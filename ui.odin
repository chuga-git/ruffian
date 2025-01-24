package ruffian
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"
import sa "core:container/small_array"

UI_LOG_RECT :: Rect{0, 39, 49, 21}
UI_INV_RECT :: Rect{49, 39, 31, 21}
UI_STATUS_RECT :: Rect{49, 0, 31, 39}

UI_Panel :: enum {
    Log,
    Inventory,
    Status,
    Popup,
}

PanelInfo :: struct {
    title: string,
    rect: Rect,
    render: proc(p: ^PanelInfo),
    redraw: bool,
}

ui := struct {
    panels: [UI_Panel]PanelInfo,
    

} {
    panels = {
        .Log = {
            "Log",
            UI_LOG_RECT,
            render_log_panel,
            true,
        },
        .Inventory = {
            "Inventory",
            UI_INV_RECT,
            render_inv_panel,
            true,
        },
        .Status = {
            "Status",
            UI_STATUS_RECT,
            render_status_panel,
            true,
        },
        .Popup = {},
    }
}



render_ui :: proc() -> (updated: bool) {
    for &p in ui.panels {
        if !p.redraw {
            continue
        }
        p->render()
        updated = true
        p.redraw = false
    }
    return
}

ui_queue_redraw :: proc(panel_type: UI_Panel) {
    ui.panels[panel_type].redraw = true
}

render_panel_fill :: proc(rect: ^Rect, title: string) {
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


render_log_panel :: proc(p: ^PanelInfo) {
    using p
    start_idx := log_buffer.line_idx

    // We want to draw the messages newest (top) to oldest (bottom)
    // Since the current index of the ring buffer is pointing at the oldest entry
    // Start at the bottom of the panel and draw upwards
    for i in 0 ..< LOG_MSG_LEN {
        cur_idx := (start_idx + i) % LOG_MSG_LEN
        entry := log_buffer.buf[cur_idx]

        if entry.len == 0 do continue

        dst := LOG_MSG_LEN - i
        for j in 0 ..< entry.len {
            draw_glyph(&terminal, {1 + j, rect.y + dst}, {entry.data[j], UI_FG_TEXT, UI_BG_DARK})
        }
    }
}

render_inv_panel :: proc(p: ^PanelInfo) {
    using p
    for &slot, idx in sa_slice(&inv_items) {
        item := item_pool_get(slot.item_type)
        count := slot.count

        write_at(
            &terminal,
            {rect.x + 1, rect.y + 1 + idx},
            fmt.tprintf("%v (%v)", item.name, count),
            UI_FG_TEXT,
            UI_BG_DARK,
        )
    }
}

render_status_panel :: proc(p: ^PanelInfo) {
    using p
    render_panel_fill(&rect, game.player.name)
    r := &rect
    s := game.player.stats
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

// Number of lines 
LOG_MSG_LEN :: 19

// How long each line can be
LOG_BUF_LEN :: 47


LogBuffer :: struct {
    buf: [LOG_MSG_LEN]struct {
        // TODO: ANSI-style color code parser so we can store glyphs instead
        data:   [LOG_BUF_LEN]int,
        len: int,
    },
    line_idx: int,
}

log_buffer: LogBuffer

log_buffer_push :: proc(msg: string) {
    wrap := utf8.rune_count_in_string(msg) >= LOG_BUF_LEN

    // At the last line, need to skip to the top to split the message
    if wrap && log_buffer.line_idx == LOG_MSG_LEN - 1 {
        log_buffer.line_idx = (log_buffer.line_idx + 1) % LOG_MSG_LEN
    }

    // Current idx is pointing at oldest slot, overwrite
    linebuf := &log_buffer.buf[log_buffer.line_idx]

    // Clear line
    mem.zero(&linebuf.data, size_of(linebuf.data))

    // copy the utf-8 runes into the buffer
    count := 1
    for r, i in msg {
        linebuf.data[i % LOG_BUF_LEN] = int(r)
        count += 1

        if wrap && i == LOG_BUF_LEN - 1 {
            linebuf.len = count
            count = 1
            log_buffer.line_idx = (log_buffer.line_idx + 1) % LOG_MSG_LEN
            linebuf = &log_buffer.buf[log_buffer.line_idx]
        }
    }

    // set new length
    linebuf.len = count

    // increment index
    log_buffer.line_idx = (log_buffer.line_idx + 1) % LOG_MSG_LEN
}

// fmt_str: static format string
// args: format args
game_log_message :: proc(fmt_str: string, args: ..any) {
    s := fmt.tprintf(fmt_str, ..args)
    log_buffer_push(s)
    ui_queue_redraw(.Log)
}