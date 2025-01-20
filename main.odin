package ruffian
import "base:runtime"
import "core:c"
import sa "core:container/small_array"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:slice"
import "core:time"
import rl "vendor:raylib"
import stbsp "vendor:stb/sprintf"

// main() context, used for logging
global_context: runtime.Context

WINDOW_WIDTH := 1920
WINDOW_HEIGHT := 1200

MAP_WIDTH :: 49
MAP_HEIGHT :: 39

Point :: [2]int
Color :: rl.Color

DirSet :: bit_set[Direction]

MAX_TURN_ENERGY :: 10

Rect :: struct {
    x: int,
    y: int,
    w: int,
    h: int,
}

Direction :: enum {
    North,
    NorthEast,
    East,
    SouthEast,
    South,
    SouthWest,
    West,
    NorthWest,
}

// clockwise from north
Dirs := [Direction]Point {
    .North     = {0, -1},
    .NorthEast = {+1, -1},
    .East      = {+1, 0},
    .SouthEast = {+1, +1},
    .South     = {0, +1},
    .SouthWest = {-1, +1},
    .West      = {-1, 0},
    .NorthWest = {-1, -1},
}

// clockwise from north
DirsCard := #partial [Direction]Point {
    .North = {0, -1},
    .East  = {+1, 0},
    .South = {0, +1},
    .West  = {-1, 0},
}

TileType :: enum {
    Empty = 0,
    Floor,
    Wall,
}

Tile :: struct {
    type:    TileType,
    visible: bool,
    seen:    bool,
}

Game :: struct {
    tiles:     #soa[MAP_WIDTH * MAP_HEIGHT]Tile,
    rooms:     [dynamic]Rect,
    entities:  [dynamic]Entity,
    map_items: map[int]Item,
    player:    ^Entity,
    turns:     int,
    turn_idx:  int,
    dirty:     bool,
}

game: Game
terminal: Terminal

in_bounds_xy :: #force_inline proc(x, y: int) -> bool {
    return x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT
}

in_bounds_point :: #force_inline proc(p: Point) -> bool {
    return p.x >= 0 && p.x < MAP_WIDTH && p.y >= 0 && p.y < MAP_HEIGHT
}

in_bounds_rect :: #force_inline proc(r: Rect) -> bool {
    return in_bounds_xy(r.x, r.y) && in_bounds_xy(r.x + r.w - 1, r.y + r.h - 1)
}

in_bounds :: proc {
    in_bounds_xy,
    in_bounds_point,
    in_bounds_rect,
}

// FIXME: the extra 1 is intentional padding to avoid adjacent rooms. Rename this proc!
rect_intersect :: #force_inline proc(r1, r2: Rect) -> bool {
    return r2.x < r1.x + r1.w + 1 && r1.x < r2.x + r2.w + 1 && r2.y < r1.y + r1.h + 1 && r1.y < r2.y + r2.h + 1
}

rect_midpoint :: #force_inline proc(r: Rect) -> Point {
    return Point{(2 * r.x + r.w) / 2, (2 * r.y + r.h) / 2}
}

rand_point_in_rect :: proc(r: Rect) -> Point {
    return {rand.int_max(r.w) + r.x, rand.int_max(r.h) + r.y}
}

set_tile_type :: proc {
    set_tile_type_xy,
    set_tile_type_point,
}

set_tile_type_xy :: #force_inline proc(x, y: int, type: TileType) {
    game.tiles[y * MAP_WIDTH + x].type = type
}

set_tile_type_point :: #force_inline proc(point: Point, type: TileType) {
    game.tiles[point.y * MAP_WIDTH + point.x].type = type
}

get_tile :: proc {
    get_tile_xy,
    get_tile_point,
}

get_tile_xy :: #force_inline proc(x, y: int) -> Tile {
    return game.tiles[y * MAP_WIDTH + x]
}

get_tile_point :: #force_inline proc(point: Point) -> Tile {
    return game.tiles[point.y * MAP_WIDTH + point.x]
}

get_tile_type :: proc {
    get_tile_type_xy,
    get_tile_type_point,
}

get_tile_type_xy :: #force_inline proc(x, y: int) -> TileType {
    return game.tiles[y * MAP_WIDTH + x].type
}

get_tile_type_point :: #force_inline proc(point: Point) -> TileType {
    return game.tiles[point.y * MAP_WIDTH + point.x].type
}

clear_tiles :: #force_inline proc() {
    for i in 0 ..< len(game.tiles) {
        game.tiles[i].type = .Empty
        game.tiles[i].visible = false
    }
}

can_move_to :: proc(pos: Point) -> bool {
    return get_tile_type(pos) == TileType.Floor
}

tile_distance :: proc(p1, p2: Point) -> int {
    return max(abs(p1.x - p2.x), abs(p1.y - p2.y))
}


tile_is_walkable :: proc(pos: Point) -> bool {
    if !in_bounds(pos) {
        return false
    }

    tile := get_tile_type(pos)
    return tile == .Floor // || tile == .OpenDoor && has no traps, etc
}

rand_point_on_map :: proc() -> Point {
    return rand_point_in_rect(game.rooms[rand.int_max(len(game.rooms))])
}

// TODO make this a callback iterator
vis_line :: proc(x0, y0, x1, y1: int) {
    x0, y0, x1, y1 := x0, y0, x1, y1
    dx := abs(x1 - x0)
    dy := -abs(y1 - y0)

    sx: int = x0 < x1 ? 1 : -1
    sy: int = y0 < y1 ? 1 : -1

    error := dx + dy
    for true {

        tile := &game.tiles[y0 * MAP_WIDTH + x0]
        if tile.type == .Floor || tile.type == .Wall {
            tile.visible = true
            tile.seen = true
            if tile.type == .Wall do break
        }
        if x0 == x1 && y0 == y1 do break
        e2 := 2 * error
        if e2 >= dy {
            error += dy
            x0 += sx
        }
        if e2 <= dx {
            error += dx
            y0 += sy
        }
    }
}

update_visibility :: proc() {
    vis_range :: int(10)

    origin := game.entities[0].pos

    {
        _, vis, _ := soa_unzip(game.tiles[:])
        mem.zero_slice(vis)
    }

    for x in origin.x - vis_range ..< origin.x + vis_range {
        vis_line(origin.x, origin.y, x, origin.y - vis_range)
        vis_line(origin.x, origin.y, x, origin.y + vis_range)
    }
    for y in origin.y - vis_range ..< origin.y + vis_range {
        vis_line(origin.x, origin.y, origin.x - vis_range, y)
        vis_line(origin.x, origin.y, origin.x + vis_range, y)
    }
    for &ent in game.entities {
        if get_tile(ent.pos).visible {
            draw_glyph(&terminal, ent.pos, ent.glyph)
        }
    }
}


FLOOR_GLYPH :: Glyph{int(Charcode.MiddleDot), rl.RAYWHITE, rl.DARKGRAY}
WALL_GLYPH :: Glyph{0x2593, rl.RAYWHITE, rl.BLACK}
sync_tiles :: proc() {
    pos: Point
    for y in 0 ..< MAP_HEIGHT {
        for x in 0 ..< MAP_WIDTH {
            glyph: Glyph
            pos = {x, y}
            tile := get_tile(x, y)
            if !tile.visible && !tile.seen {
                clear_glyph(&terminal, pos)
                continue
            }

            switch tile.type {
            case .Empty:
                clear_glyph(&terminal, pos)
                continue
            case .Floor:
                glyph = FLOOR_GLYPH
            case .Wall:
                glyph = WALL_GLYPH
            }

            if !tile.visible {
                glyph.fg = rl.ColorAlpha(glyph.fg, 0.75)
                glyph.bg = rl.ColorAlpha(glyph.bg, 0.75)
            }
            draw_glyph(&terminal, pos, glyph)
        }
    }

    // sync entities
    for &ent in game.entities {
        tile := get_tile(ent.pos)
        // if !tile.visible do continue
        draw_glyph(&terminal, ent.pos, ent.glyph)
    }
}


// TODO: AI processing queue?
update_monsters :: proc() {
    for &m in game.entities {
        if &m == game.player do continue

        min_so_far := DMAP_MAX_UNINIT
        next_dir: Point
        for dir in Dirs {
            pos := m.pos + dir
            if !tile_is_walkable(pos) do continue
            if e := entity_at(pos); e != nil && e != game.player do continue

            dmap_val := DMaps.player[point_idx(pos)]
            if dmap_val < min_so_far {
                min_so_far = dmap_val
                next_dir = dir
            }
        }

        m.next_action = ActionMove{next_dir}
    }
}

game_update :: proc() {
    for true {
        cur_ent := &game.entities[game.turn_idx]

        if cur_ent.energy >= MAX_TURN_ENERGY && cur_ent.next_action == nil {
            return
        }
        update_monsters()
        // Not idling on input, something needs to be refreshed (probably)
        // TODO: this should only happen when entity is visible
        game.dirty = true

        for true {
            cur_ent = &game.entities[game.turn_idx]
            cur_ent.energy += cur_ent.stats.agi
            if cur_ent.energy >= MAX_TURN_ENERGY {
                // fmt.println("here")
                if cur_ent.next_action == nil {
                    return
                }
                break
            } else {
                game.turn_idx = (game.turn_idx + 1) % len(game.entities)
            }
        }

        success, alternate := do_action(cur_ent)

        for alternate != nil {
            cur_ent.next_action = alternate
            success, alternate = do_action(cur_ent)
        }

        // TODO
        cur_ent.energy = 0
        cur_ent.next_action = nil

        if success {
            game.turn_idx = (game.turn_idx + 1) % len(game.entities)
        }
    }
}


init_game :: proc() {
    game.entities = make([dynamic]Entity)
    game.rooms = make([dynamic]Rect)
    game.turns = 1
    game.dirty = true
}

destroy_game :: proc() {
    delete(game.entities)
    delete(game.rooms)
}

init_window :: proc(w, h: i32) {
    // initialize window context
    rl.SetConfigFlags(rl.ConfigFlags{.VSYNC_HINT})
    rl.InitWindow(w, h, "Ruffian")
    rl.SetTargetFPS(30)
}

destroy_window :: proc() {
    rl.CloseWindow()
}

main :: proc() {
    // Initialize logger, https://github.com/odin-lang/examples/blob/master/raylib/log/main.odin
    context.logger = log.create_console_logger(.Debug, log.Options{.Level, .Short_File_Path, .Time})

    global_context = context
    rl.SetTraceLogLevel(.ALL)
    rl.SetTraceLogCallback(proc "c" (rl_level: rl.TraceLogLevel, message: cstring, args: ^c.va_list) {
        context = global_context

        level: log.Level
        switch rl_level {
        case .TRACE, .DEBUG:
            level = .Debug
        case .INFO:
            level = .Info
        case .WARNING:
            level = .Warning
        case .ERROR:
            level = .Error
        case .FATAL:
            level = .Fatal
        case .ALL, .NONE:
            fallthrough
        case:
            log.panicf("unexpected log level %v", rl_level)
        }

        @(static) buf: [dynamic]byte
        log_len: i32
        for {
            buf_len := i32(len(buf))
            log_len = stbsp.vsnprintf(raw_data(buf), buf_len, message, args)
            if log_len <= buf_len {
                break
            }

            non_zero_resize(&buf, max(128, len(buf) * 2))
        }

        context.logger.procedure(context.logger.data, level, string(buf[:log_len]), context.logger.options)
    })

    CONWIDTH :: 80
    CONHEIGHT :: 60

    init_window(20 * i32(CONWIDTH), 20 * i32(CONHEIGHT))
    defer destroy_window()

    terminal = init_terminal(
        width = CONWIDTH,
        height = CONHEIGHT,
        char_width = 20,
        char_height = 20,
        fg = rl.WHITE,
        bg = UI_BG_DARK,
        atlas_filepath = "resources/cp437_20x20.png",
    )
    defer destroy_terminal(&terminal)

    assert(MAP_WIDTH < terminal.width)
    assert(MAP_HEIGHT < terminal.height)


    init_game()
    defer destroy_game()

    generate_level()

    init_player()
    make_monster(.Troll)

    // FIXME DEBUG
    {
        d := &DMaps.player
        DMap_clear(d)
        DMap_calc(d, game.player.pos)
    }
    render_ui()

    start_time := rl.GetTime()
    for !rl.WindowShouldClose() {
        handle_input()

        if rl.IsMouseButtonPressed(.LEFT) {
            mpos := get_mouse_grid_pos()
            debug_spawn_monster(mpos)
        }

        game_update()

        // sync game with terminal
        if game.dirty {
            DMap_clear(&DMaps.player)
            DMap_calc(&DMaps.player, game.player.pos)
            update_visibility()
            sync_tiles()
            render_ui()
        }

        rl.BeginDrawing()
        terminal_render(&terminal, game.dirty)

        debug_draw_dmap()

        rl.EndDrawing()

        game.dirty = false

        // TODO: only need to do this if specific draw procs have been called (delegate from global state struct?)
        free_all(context.temp_allocator)
    }
}


TEST_COLORS := [?]rl.Color {
    rl.YELLOW,
    rl.GOLD,
    rl.ORANGE,
    rl.PINK,
    rl.RED,
    rl.GRAY,
    rl.MAROON,
    rl.GREEN,
    rl.LIME,
    rl.DARKGREEN,
    rl.SKYBLUE,
    rl.BLUE,
    rl.DARKBLUE,
    rl.PURPLE,
    rl.VIOLET,
    rl.LIGHTGRAY,
    rl.DARKPURPLE,
    rl.BEIGE,
    rl.BROWN,
    rl.MAGENTA,
}

get_mouse_grid_pos :: proc() -> Point {
    mx := rl.GetMouseX()
    my := rl.GetMouseY()

    cw := terminal.char_width
    ch := terminal.char_height

    px := int(mx) / (cw)
    py := int(my) / (ch)
    return {px, py}
}

draw_mouse_coords :: proc() {
    mx := rl.GetMouseX()
    my := rl.GetMouseY()

    cw := terminal.char_width
    ch := terminal.char_height

    px := mx / i32(cw)
    py := my / i32(ch)

    rl.DrawText(rl.TextFormat("%d, %d", px, py), i32(WINDOW_WIDTH / 2 - 32), 0, 32, rl.WHITE)
    rl.DrawText(rl.TextFormat("%d, %d", mx, my), i32(WINDOW_WIDTH / 2 - 32), 32, 32, rl.WHITE)
}

hover_highlight :: proc(mx, my: i32) {
    ww, yy := terminal.char_width, terminal.char_height
    cw, ch := i32(ww), i32(yy)
    // cw *= 2
    // ch *= 2
    x := mx / i32(cw) * i32(cw)
    y := my / i32(ch) * i32(ch)
    // rl.DrawRectangleLines(x, y, i32(cw) * 2, i32(ch) * 2, rl.RED)
    rl.DrawRectangleLinesEx({f32(x), f32(y), f32(cw), f32(ch)}, 1, rl.RED)
}

draw_gridlines :: proc() {
    alpha :: f32(1.0)
    linecolor :: rl.GREEN
    cw, ch := terminal.char_width, terminal.char_height
    for y in 0 ..< terminal.height {
        rl.DrawLineEx({0, f32(y * ch)}, {f32(terminal.width * cw), f32(y * ch)}, 1, rl.ColorAlpha(linecolor, alpha))
    }
    for x in 0 ..< terminal.width {
        rl.DrawLineEx({f32(x * cw), 0}, {f32(x * cw), f32(terminal.height * ch)}, 1, rl.ColorAlpha(linecolor, alpha))
    }
}

// ex: `draw_test_grid({0, 0, 10, 10})` draws a 10x10 grid with origin at (0, 0) terminal space
draw_test_grid :: proc(r: Rect) {
    for y in r.y ..< r.y + r.h {
        for x in r.x ..< r.x + r.w {
            cidx := (y * r.w + x) % len(TEST_COLORS)
            col := TEST_COLORS[cidx]
            rl.DrawRectangle(
                i32(x * terminal.char_width),
                i32(y * terminal.char_height),
                i32(terminal.char_width),
                i32(terminal.char_height),
                col,
            )
        }
    }
}

debug_print_dmap :: proc() {
    d := &DMaps.player

    for y in 0 ..< MAP_HEIGHT {
        for x in 0 ..< MAP_WIDTH {
            dval := d[point_idx({x, y})]

            fmt.print(dval, " ")
        }
        fmt.println()
    }
}

debug_draw_dmap :: proc() {
    d := &DMaps.player

    for y in 0 ..< MAP_HEIGHT {
        for x in 0 ..< MAP_WIDTH {
            dval := d[point_idx({x, y})]
            color: Color
            if dval > 99 {
                dval = 99
                color = rl.BLACK
            } else {
                color = rl.ColorFromHSV(f32((dval * 6) % 360), 1, 1)
            }


            color = rl.ColorAlpha(color, 0.25)
            r := [4]i32 {
                i32(x * terminal.char_width),
                i32(y * terminal.char_height),
                i32(terminal.char_width),
                i32(terminal.char_height),
            }
            rl.DrawRectangle(r.x, r.y, r.w, r.z, color)
            if dval < 99 do rl.DrawText(rl.TextFormat("%d", dval), r.x + r.z / 4, r.y + r.z / 2, r.z / 2, rl.BLACK)
        }
    }
}

debug_spawn_monster :: proc(p: Point) {
    if !tile_is_walkable(p) || entity_at(p) != nil do return

    make_monster(.Troll, p)
}
