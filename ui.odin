package ruffian
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"


UI_BG_DARK :: Color{26, 26, 26, 255}
UI_FG_BLUE :: Color{0, 70, 140, 255}
UI_FG_TEXT :: Color{158, 158, 158, 255}

UI_LOG_RECT :: Rect{0, 39, 49, 21}
UI_INV_RECT :: Rect{49, 39, 31, 21}
UI_STATUS_RECT :: Rect{49, 0, 31, 39}

render_panel :: proc(rect: Rect, title: string) {
    assert(len(title) < rect.w)
    fg := UI_FG_BLUE
    bg := UI_BG_DARK
    a := Point{rect.x, rect.y}
    b := Point{rect.x + rect.w - 1, rect.y}
    c := Point{rect.x, rect.y + rect.h - 1}
    d := Point{rect.x + rect.w - 1, rect.y + rect.h - 1}

    // Place corners
    draw_glyph(&terminal, a, {int('╒'), fg, bg})
    draw_glyph(&terminal, b, {int('╕'), fg, bg})
    draw_glyph(&terminal, c, {int('└'), fg, bg})
    draw_glyph(&terminal, d, {int('┘'), fg, bg})

    // Place vertical sides
    for y in rect.y + 1 ..< rect.y + rect.h - 1 {
        draw_glyph(&terminal, {rect.x, y}, {int('│'), fg, bg})
        draw_glyph(&terminal, {rect.x + rect.w - 1, y}, {int('│'), fg, bg})
    }

    // Place horizontal sides
    for x in rect.x + 1 ..< rect.x + rect.w - 1 {
        draw_glyph(&terminal, {x, rect.y}, {int('═'), fg, bg})
        draw_glyph(&terminal, {x, rect.y + rect.h - 1}, {int('─'), fg, bg})
    }

    // Carve out title
    //    place a =| (rect.x + 2)
    //    draw text  (rect.x + 3)
    //    place a |= (rect.x + 2 + len(title) + 1)
    draw_glyph(&terminal, {rect.x + 2, rect.y}, {int('╡'), fg, bg})
    draw_glyph(&terminal, {rect.x + 2 + len(title) + 1, rect.y}, {int('╞'), fg, bg})
    write_at(&terminal, {rect.x + 3, rect.y}, title, UI_FG_TEXT, bg)

    // fill in background
    for y in rect.y + 1 ..< rect.y + rect.h - 1 {
        for x in rect.x + 1 ..< rect.x + rect.w - 1 {
            draw_glyph(&terminal, {x, y}, {0, fg, bg})
        }
    }
}


// Number of lines 
LOG_MSG_LEN :: 19

// How long each line can be
LOG_BUF_LEN :: 47

// TODO: store glyphs instead
LogEntry :: struct {
    data:   [LOG_BUF_LEN]int,
    length: int,
}

// TODO: We should have a struct for each panel so they can indicate if they need to be redrawn individually
LogBuffer :: struct {
    buf: [LOG_MSG_LEN]LogEntry,
    idx: int,
}

log_buffer: LogBuffer

// TODO: handle empty case (maybe just have a proc for zeroing the line?)
// Does not free the string
log_buffer_push :: proc(msg: string) {
    assert(len(msg) < LOG_BUF_LEN) // TODO: handle wrap case

    // current idx is pointing at oldest slot, overwrite
    idx := log_buffer.idx

    // zero out the buffer data
    mem.zero(&log_buffer.buf[idx].data, len(log_buffer.buf[idx].data))

    // copy the utf-8 runes into the buffer
    count := 1
    for r, i in msg {
        log_buffer.buf[idx].data[i] = int(r)
        count += 1
    }

    // set new length
    log_buffer.buf[idx].length = count

    // increment index
    log_buffer.idx = (log_buffer.idx + 1) % LOG_MSG_LEN
}

render_log_panel :: proc() {
    render_panel(UI_LOG_RECT, "Log")

    start_idx := log_buffer.idx

    // We want to draw the messages newest (top) to oldest (bottom)
    // Since the current index of the ring buffer is pointing at the oldest entry
    // Start at the bottom of the panel and draw upwards
    for i in 0 ..< LOG_MSG_LEN {
        cur_idx := (start_idx + i) % LOG_MSG_LEN
        entry := log_buffer.buf[cur_idx]

        if entry.length == 0 do continue

        dst := LOG_MSG_LEN - i
        for j in 0 ..< entry.length {
            draw_glyph(&terminal, {1 + j, UI_LOG_RECT.y + dst}, {entry.data[j], UI_FG_TEXT, UI_BG_DARK})
        }
    }
}

render_inv_panel :: proc() {
    render_panel(UI_INV_RECT, "Inventory")
    for &slot, idx in sa_slice(&inv_items) {
        item := item_pool_get(slot.item_type)
        count := slot.count

        write_at(
            &terminal,
            {UI_INV_RECT.x + 1, UI_INV_RECT.y + 1 + idx},
            fmt.tprintf("%v %v", count, item.name),
            UI_FG_TEXT,
            UI_BG_DARK,
        )
    }
}

render_status_panel :: proc() {
    render_panel(UI_STATUS_RECT, game.player.name)
    r := UI_STATUS_RECT
    s := &game.player.stats
    lines := [?]string {
        fmt.tprintf("HP       %v / %v", s.hp, s.max_hp),
        fmt.tprintf("AC       %v", s.ac),
        fmt.tprintf("Str      %v", s.str),
        fmt.tprintf("Agi      %v", s.agi),
        fmt.tprintf("For      %v", s.fort),
        fmt.tprintf("Int      %v", s.intl),
        fmt.tprintf("Wil      %v", s.wil),
        fmt.tprintf("Dodge    %v", s.dodge),
        fmt.tprintf("M Atk    %v", s.dodge),
    }

    for i in 0 ..< len(lines) {
        line := lines[i]
        write_at(&terminal, {r.x + 1, r.y + 1 + i}, line, UI_FG_TEXT, UI_BG_DARK)
    }

    hands := equipped_slots[.Hands]
    armor := equipped_slots[.Armor]
    ring := equipped_slots[.Ring]
    equip_lines := [?]string {
        (hands == nil) ? "«hands»" : fmt.tprint(hands.name),
        (armor == nil) ? "«armor»" : fmt.tprint(armor.name),
        (ring == nil) ? "«ring»" : fmt.tprint(ring.name),
    }

    for i in 0 ..< len(equip_lines) {
        line := equip_lines[i]
        write_at(&terminal, {r.x + 1, r.y + 1 + len(lines) + 2 + i}, line, UI_FG_TEXT, UI_BG_DARK)
    }
}

render_ui :: proc() {
    render_log_panel()
    render_inv_panel()
    render_status_panel()
}

// fmt_str: static format string
// args: format args
// Allocated with temp allocator. Freed at end of frame!
game_log_message :: proc(fmt_str: string, args: ..any) {
    s := fmt.tprintf(fmt_str, ..args)
    fmt.println(s)
    log_buffer_push(s)
    game.dirty = true // TODO
}
