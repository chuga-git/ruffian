package ruffian
import "core:c"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

FontAtlas :: struct {
    texture:     rl.Texture,

    // Atlas texture width in pixels
    width:       int,

    // Atlas texture height in pixels
    height:      int,

    // Char width in pixels
    char_width:  int,

    // Char height in pixels
    char_height: int,

    // Number of rows in atlas image
    rows:        int,
    // Number of columns in atlas image
    cols:        int,

    // Rune to CP437 index map
    char_map:    map[int]int,
}

Glyph :: struct {
    // cp437/char_rects index
    char: int,

    // foreground color
    fg:   Color,

    // background color
    bg:   Color,
}

Terminal :: struct {
    // Number of glyphs
    width:         int,
    height:        int,
    char_width:    int,
    char_height:   int,
    atlas:         FontAtlas,
    glyphs:        #soa[]Glyph,
    new_glyphs:    #soa[]Glyph,

    // codepoint -> char index -> rect
    char_rects:    [256]rl.Rectangle,

    // Screen render texture. Updated from fg_render_tex and bg_tex each redraw.
    render_tex:    rl.RenderTexture,

    // foreground render texture
    fg_render_tex: rl.RenderTexture,

    // background texture
    bg_tex:        rl.Texture,

    // bg_image holds 1 pixel for each glyph and is drawn onto the scaled bg texture
    // TODO: benchmark this
    bg_image:      rl.Image,
    flip_src:      rl.Rectangle,
    flip_dst:      rl.Rectangle,
    fg_default:    Color,
    bg_default:    Color,
    is_updated:    bool,
}

init_terminal :: proc(
    width, height, char_width, char_height: int,
    fg, bg: Color,
    atlas_filepath: string,
) -> (
    term: Terminal,
) {
    term.width = width //WINDOW_WIDTH / char_width
    term.height = height //WINDOW_HEIGHT / char_height
    term.char_width = char_width
    term.char_height = char_height

    term.glyphs = make(#soa[]Glyph, term.width * term.height)
    term.new_glyphs = make(#soa[]Glyph, term.width * term.height)

    for i in 0 ..< len(term.glyphs) {
        term.glyphs[i].char = 1
        term.glyphs[i].fg = rl.RED
        term.glyphs[i].bg = rl.RED
    }

    term.atlas = init_font_atlas(atlas_filepath, char_width, char_height)

    init_render_textures(&term)

    term.fg_default = fg
    term.bg_default = bg
    clear_term(&term)
    term.is_updated = false
    return
}

destroy_terminal :: proc(term: ^Terminal) {
    destroy_font_atlas(&term.atlas)

    rl.UnloadRenderTexture(term.render_tex)
    rl.UnloadRenderTexture(term.fg_render_tex)

    rl.UnloadTexture(term.bg_tex)
    rl.UnloadImage(term.bg_image)

    delete(term.glyphs)
    delete(term.new_glyphs)
}

init_render_textures :: proc(term: ^Terminal) {
    init_char_rects(term)

    cw, ch := term.atlas.char_width, term.atlas.char_height
    term.render_tex = rl.LoadRenderTexture(i32(term.width * cw), i32(term.height * ch))
    term.fg_render_tex = rl.LoadRenderTexture(i32(term.width * cw), i32(term.height * ch))

    term.bg_image = rl.GenImageColor(i32(term.width), i32(term.height), rl.BLANK)
    term.bg_tex = rl.LoadTextureFromImage(term.bg_image)

    term.flip_src = {0, 0, f32(term.render_tex.texture.width), f32(-term.render_tex.texture.height)}
    term.flip_dst = {0, 0, f32(term.render_tex.texture.width), f32(term.render_tex.texture.height)}
}

init_char_rects :: proc(term: ^Terminal) {
    for y in 0 ..< term.atlas.rows {
        for x in 0 ..< term.atlas.cols {
            term.char_rects[y * term.atlas.cols + x] = rl.Rectangle {
                f32(x * term.atlas.char_width),
                f32(y * term.atlas.char_height),
                f32(term.atlas.char_width),
                f32(term.atlas.char_height),
            }
        }
    }
}


// Creates a FontAtlas struct with given filename and char width/height (square width x height layout)
init_font_atlas :: proc(filename: string, cw, ch: int) -> (atlas: FontAtlas) {
    atlas.texture = load_font_texture(filename)

    atlas.width = int(atlas.texture.width)
    atlas.height = int(atlas.texture.height)

    atlas.char_width = cw
    atlas.char_height = ch

    atlas.cols = atlas.width / atlas.char_width
    atlas.rows = atlas.height / atlas.char_height
    atlas.char_map = make(map[int]int)

    // initialize rune to codepoint index map
    for i in 0 ..< len(CODEPOINTS) {
        atlas.char_map[CODEPOINTS[i]] = i
    }

    return
}

destroy_font_atlas :: proc(atlas: ^FontAtlas) {
    rl.UnloadTexture(atlas.texture)
    delete(atlas.char_map)
}

load_font_texture :: proc(filename: string) -> rl.Texture {
    filename := strings.clone_to_cstring(filename, context.temp_allocator)

    // TODO: This is probably not portable outside of REXPaint CP437 fonts. Don't need to do this with images that have transparency.
    // Compare # of channels? (or just use odin png?)
    image := rl.LoadImage(filename)

    // If the PNG only has RGB channels, it needs to be reformatted with an alpha channel
    rl.ImageFormat(&image, .UNCOMPRESSED_R8G8B8A8)

    // Key in the transparency (only works for black backgrounds)
    rl.ImageColorReplace(&image, {0, 0, 0, 255}, {0, 0, 0, 0})

    texture := rl.LoadTextureFromImage(image)

    rl.UnloadImage(image)

    // free filename string
    free_all(context.temp_allocator)

    return texture
}


terminal_update :: proc(term: ^Terminal) -> (bool, bool) {
    if term.is_updated do return false, false
    // FIXME
    // term.is_updated = true

    image_changed := false
    fg_changed := false
    rl.BeginTextureMode(term.fg_render_tex)
    for y in 0 ..< term.height {
        for x in 0 ..< term.width {
            idx := y * term.width + x

            // position in unscaled screen space
            pos := rl.Vector2{f32(x * term.char_width), f32(y * term.char_height)}

            new_glyph := term.new_glyphs[idx]
            old_glyph := term.glyphs[idx]


            // Update background color 
            if new_glyph.bg != old_glyph.bg {
                rl.ImageDrawPixel(&term.bg_image, i32(x), i32(y), new_glyph.bg)
                term.glyphs[idx].bg = new_glyph.bg
                image_changed = true
            }

            // Update glyph and foreground color
            if new_glyph.char != old_glyph.char || new_glyph.fg != old_glyph.fg {
                fg_changed = true
                // FIXME?
                // if new_glyph.char == 0 do continue

                rl.BeginScissorMode(
                    i32(x * term.char_width),
                    i32(y * term.char_height),
                    i32(term.char_width),
                    i32(term.char_height),
                )
                rl.ClearBackground(rl.BLANK)
                rl.DrawTextureRec(term.atlas.texture, term.char_rects[new_glyph.char], pos, new_glyph.fg)
                rl.EndScissorMode()

                term.glyphs[idx].char = new_glyph.char
                term.glyphs[idx].fg = new_glyph.fg
            }
        }
    }
    rl.EndTextureMode()

    if image_changed do rl.UpdateTexture(term.bg_tex, term.bg_image.data)
    return image_changed, fg_changed
}

terminal_updates := 0
terminal_render :: proc(term: ^Terminal, should_update: bool) -> (bool, bool) {
    bg_updated := false
    fg_updated := false
    rl.ClearBackground(UI_BG_DARK)
    if should_update {
        terminal_updates += 1
        bg_updated, fg_updated = terminal_update(term)
        fmt.println("Terminal updates: ", terminal_updates, bg_updated, fg_updated)

        if bg_updated || fg_updated {
            rl.BeginTextureMode(term.render_tex)
            rl.ClearBackground(rl.BLANK)

            // TODO: this scaling approach only works for NxN fonts
            rl.DrawTextureEx(term.bg_tex, {}, 0, f32(term.char_width), rl.WHITE)
            rl.DrawTexturePro(term.fg_render_tex.texture, term.flip_src, term.flip_dst, {}, 0, rl.WHITE)
            rl.EndTextureMode()
        }

        term.is_updated = true
    }

    rl.DrawTexturePro(term.render_tex.texture, term.flip_src, term.flip_dst, {}, 0.0, rl.WHITE)
    return bg_updated, fg_updated
}


term_in_bounds :: proc(term: ^Terminal, pos: Point) -> bool {
    return pos.x >= 0 && pos.x < terminal.width && pos.y >= 0 && pos.y < terminal.height
}

// draw_glyph :: proc(term: ^Terminal, x, y: int, char: rune, foreground: Maybe(Color), background: Maybe(Color)) {
draw_glyph :: proc(term: ^Terminal, pos: Point, glyph: Glyph) {
    idx := pos.y * (term.width) + pos.x
    cp := term.atlas.char_map[glyph.char]
    term.new_glyphs[idx] = {cp, glyph.fg, glyph.bg}
    term.is_updated = false
    // set_char(term, idx, cp)
    // set_foreground(term, idx, glyph.fg)
    // set_background(term, idx, glyph.bg)

    // if fg, ok := foreground.?; ok {
    //     set_foreground(term, idx, fg)
    // }

    // if bg, ok := background.?; ok {
    //     set_background(term, idx, bg)
    // }
}

write_at :: proc(term: ^Terminal, pos: Point, str: string, fg, bg: Color) {
    for cp, idx in str {
        draw_glyph(term, {pos.x + idx, pos.y}, {int(cp), fg, bg})
    }
}

clear_glyph :: proc(term: ^Terminal, pos: Point) {
    draw_glyph(term, pos, {0, 0, 0}) //term.fg_default, term.bg_default}) // use the default colors...?
}

clear_term :: proc(term: ^Terminal) {
    for i in 0 ..< len(term.new_glyphs) {
        term.new_glyphs[i].char = 0
        term.new_glyphs[i].fg = term.fg_default
        term.new_glyphs[i].bg = term.bg_default
    }
}

set_char :: proc(term: ^Terminal, idx, char: int) {
    term.new_glyphs[idx].char = char
}

set_foreground :: proc(term: ^Terminal, idx: int, fg: Color) {
    term.new_glyphs[idx].fg = fg
}

set_background :: proc(term: ^Terminal, idx: int, bg: Color) {
    term.new_glyphs[idx].bg = bg
}
