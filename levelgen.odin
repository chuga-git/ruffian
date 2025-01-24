package ruffian
import "core:math/rand"
import "core:mem"
import "core:slice"


generate_level :: proc() {
    generate_map()
    place_monsters()
    place_items()    
}

place_monsters :: proc() {
    monster_count := 1 + rand.int_max(3)
    for i in 0..<monster_count {
        kind, _ := rand.choice_bit_set(MONSTER_TYPES) // don't need to check ok, this will never fail.
        make_monster_rand(kind)
    }
    // TODO log count
}

place_items :: proc() {
    item_count := 1 + rand.int_max(2)
    for i := item_count; i >= 0; {
        pos := rand_point_on_map()

        // don't stack them (for now)
        if ok := pos in game.map_items; ok do continue

        kind := rand.choice_enum(ItemType)
        game.map_items[pos] = kind
        i -= 1
    }
    // TODO log count
}

generate_map :: proc() {
    for i in 0 ..< len(game.tiles) do game.tiles[i].type = .Wall
    clear(&game.rooms)
    
    MAX_TRIES :: 50
    tries := MAX_TRIES
    placement: for tries > 0 {
        rect := rand_room_rect()
        for &room in game.rooms {
            if room == {} do continue
            if rect_intersect(rect, room) {
                tries -= 1
                continue placement
            }
        }

        append(&game.rooms, rect)

        for y in rect.y ..< rect.y + rect.h {
            for x in rect.x ..< rect.x + rect.w {
                set_tile_type(x, y, TileType.Floor)
            }
        }
    }
    make_tunnels()
}

rand_room_rect :: proc() -> (r: Rect) {
    // i in [0, 5] gives 3->13 odd. Odd width, height in [3, map_width), [3, map_height) 
    r.w = 3 + 2 * rand.int_max(5)
    r.h = 3 + 2 * rand.int_max(5) // FIXME: this needs to be parameterized 
    r.x = 1 + 2 * rand.int_max((MAP_WIDTH - r.w) / 2)
    r.y = 1 + 2 * rand.int_max((MAP_HEIGHT - r.h) / 2)
    assert(r.w % 2 == 1 && r.h % 2 == 1)
    assert(r.x % 2 == 1 && r.y % 2 == 1)
    return
}

carve_line :: proc(x0, y0, x1, y1: int) {
    x0, y0, x1, y1 := x0, y0, x1, y1
    dx := abs(x1 - x0)
    dy := -abs(y1 - y0)

    sx: int = x0 < x1 ? 1 : -1
    sy: int = y0 < y1 ? 1 : -1

    error := dx + dy
    for true {
        if get_tile_type(x0, y0) != TileType.Floor do set_tile_type(x0, y0, TileType.Floor)
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

carve_tunnel :: proc(start, end: Point) {
    corner: Point
    if rand.int_max(2) > 0 {
        corner = Point{end.x, start.y}
    } else {
        corner = Point{start.x, end.y}
    }

    carve_line(start.x, start.y, corner.x, corner.y)
    carve_line(corner.x, corner.y, end.x, end.y)
}

make_tunnels :: proc() {
    start_room := &game.rooms[0]
    start_midpoint := rect_midpoint(start_room^)
    for &end_room in game.rooms[1:] {
        carve_tunnel(start_midpoint, rect_midpoint(end_room))
    }
}

// TODO: salvage this
//generate_level :: proc() {
// assert(MAP_WIDTH % 2 == 1 && MAP_HEIGHT % 2 == 1, "Map dimensions are not odd!")


// clear(&game.rooms)
// for i in 0..<len(game.tiles) do game.tiles[i] = .Wall

// regions := make([]int, MAP_WIDTH*MAP_HEIGHT)
// defer delete(regions)

// current_region := 0

// // place rooms
// MAX_TRIES :: 20
// tries := MAX_TRIES
// placement: for tries > 0 {
//     rect := rand_room_rect()
//     for &room in game.rooms {
//         if rect_intersect(rect, room.rect) { 
//             tries -= 1
//             continue placement
//         }
//     }

//     room := Room{rect}
//     append(&game.rooms, room)

//     current_region += 1

//     for y in rect.y..<rect.y+rect.h {
//         for x in rect.x..<rect.x+rect.w {
//             pos := Point{x, y}
//             set_tile_type(pos, TileType.Floor)
//             regions[pos.y * MAP_WIDTH + pos.x] = current_region
//         }
//     }
// }

// // cast lines from every side until we have a spanning tree
// for &room in game.rooms {
//     using room
//     a, b, c, d : Point
//     a = {rect.x, rect.y}
//     b = {rect.x+rect.w-1, rect.y}
//     c = {rect.x, rect.y+rect.h-1}
//     d = {rect.x+rect.w-1, rect.y+rect.h-1}

//     valid_exits : [dynamic]Point
//     valid_exits = make([dynamic]Point); defer delete(valid_exits)

//     // a->b
//     for x in a.x..<b.x {

//     }


// }


// connect rooms with mazes
// for y : int = 1; y < MAP_HEIGHT; y += 2 {
//     for x: int = 1; x < MAP_WIDTH; x += 2 {
//         start := Point{x, y}
//         if get_tile_type(start) != TileType.Wall do continue

//         cells := make([dynamic]Point)
//         defer delete(cells)

//         last_dir : Direction

//         current_region += 1

//         set_tile_type(start, TileType.Floor)
//         regions[start.y * MAP_WIDTH + start.x] = current_region

//         append(&cells, start)
//         for len(cells) > 0 {
//             cell := cells[len(cells)-1]
//             unmade_cells := bit_set[Direction]{}
//             for dir_vec, dir in DirsCard {
//                 if can_carve(cell, dir_vec) do unmade_cells += {dir}
//             }

//             if unmade_cells != {} {
//                 dir: Direction
//                 if last_dir in unmade_cells { // && rng.range(100) > winding_percent
//                     dir = last_dir
//                 } else {
//                     dir, _ = rand.choice_bit_set(unmade_cells)
//                 }

//                 set_tile_type(cell, TileType.Floor)

//                 next := cell + DirsCard[dir]

//                 set_tile_type(next, TileType.Floor)
//                 regions[next.y * MAP_WIDTH + next.x] = current_region

//                 next += DirsCard[dir]

//                 set_tile_type(next, TileType.Floor)
//                 regions[next.y * MAP_WIDTH + next.x] = current_region

//                 append(&cells, next)
//                 last_dir = dir
//             } else {
//                 pop(&cells)
//                 last_dir = Direction.NoDir
//             }
//         }
//     }
// }


// // Connect regions together

// // maps (x, y) Points to region numbers
// connector_regions: map[Point]map[int]struct{}
// connector_regions = make(map[Point]map[int]struct{}); defer delete(connector_regions)

// for y in 1..<MAP_HEIGHT-1 {
//     for x in 1..<MAP_WIDTH-1 {
//         pos := Point{x, y}
//         if get_tile_type(pos) != TileType.Wall do continue

//         connector_regions[pos] = make(map[int]struct{})
//         temp := &connector_regions[pos]
//         for dir in DirsCard {
//             new_pos := pos + dir
//             region := regions[new_pos.y * MAP_WIDTH + new_pos.x]
//             // add region number to this point's set
//             if region != 0 {
//                 temp^[region] = {}
//             }
//         }

//         if len(temp^) < 2 {
//             delete_key(&connector_regions, pos)
//         }
//     }
// }

// connectors: [dynamic]Point
// {
//     temp := slice.map_keys(connector_regions) or_else panic("Allocator failure")
//     connectors = slice.into_dynamic(temp)
// }
// defer delete(connectors)

// merged := make(map[int]int); defer delete(merged)
// open_regions := make(map[int]struct{}); defer delete(open_regions)

// for i in 0..=current_region {
//     merged[i] = i
//     open_regions[i] = {}
// }

// for len(open_regions) > 1 {
//     connector := rand.choice(connectors[:])

//     // carve
//     set_tile_type(connector, TileType.Door)

//     _regions: []int

//     _regions, _ = slice.map_keys(connector_regions[connector]); defer delete(_regions)
//     for i in 0..<len(regions) {
//         _regions[i] = merged[i]
//     }


//     dest: int
//     sources: []int
//     dest = _regions[0]
//     sources = _regions[1:]

//     for i in 0..<current_region {
//         if slice.contains(sources, merged[i]) {
//             merged[i] = dest
//         }
//     }

//     for key in sources {
//         if ok := key in open_regions; !ok {
//             delete_key(&open_regions, key)
//         }
//     }

//     {
//         temp := make([dynamic]Point) or_else panic("Allocator error")
//         for pos in connectors {
//             if diff := connector - pos; diff.x < 2 && diff.y < 2 do continue
//             // I've come to the realization that I may not be very good at this programming thing after all
//             // __regions := slice.mapper(connector_regions[pos], )
//         }
//     }
// }
//     rand_room_rect :: proc() -> (r: Rect) {
//         // i in [0, 5] gives 3->13 odd. Odd width, height in [3, map_width), [3, map_height) 
//         r.w = 3 + 2*rand.int_max(6)
//         r.h = 3 + 2*rand.int_max(6) // FIXME: this needs to be parameterized 
//         assert(r.w % 2 == 1 && r.h % 2 == 1)
//         // odd x and y in [1, map_width), [1, map_height). Constraints:
//         // x < map_width
//         // x + width < map_width        Translate x by rect width. 
//         // x < map_width - map_width    Notice the strict inequality still holds.
//         // x < map_width - width - 1    Subtract 1 since we have a lower bound offset
//         r.x = 1 + 2*rand.int_max((MAP_WIDTH - r.w) / 2)
//         r.y = 1 + 2*rand.int_max((MAP_HEIGHT - r.h) / 2)
//         assert(in_bounds_rect(r), "Rect not in bounds.") // FIXME: Remove these asserts after this is tested. This math shouldn't ever break.
//         assert(r.x % 2 == 1 && r.y % 2 == 1)
//         return
//     }

//     can_carve :: proc(pos, dir: Point) -> bool {
//         if !in_bounds(pos + 3*dir) do return false
//         return get_tile_type(pos + 2*dir) == TileType.Wall
//     }
// }
