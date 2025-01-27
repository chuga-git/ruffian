package ruffian
import "core:fmt"
import rl "vendor:raylib"

// Game input commands directly affecting game state, maps to multiple keycodes
// Vim keys:
// y j u
// h   l
// b k n
InputCommand :: enum {
    None,
    Up,
    Down,
    Left,
    Right,
    UpLeft,
    UpRight,
    DownLeft,
    DownRight,
    Neutral, // KP5

    Accept,
    Cancel,

    OpenWield,

    SelectOne,
    SelectTwo,
    SelectThree,
    SelectFour,
    SelectFive,
    SelectSix,
    SelectSeven,
    SelectEight,
    SelectNine,
    SelectTen,


}

UI_STATE_TRIGGERS := bit_set[InputCommand] {
    .SelectOne,
    .SelectTwo,
    .SelectThree,
    .SelectFour,
    .SelectFive,
    .SelectSix,
    .SelectSeven,
    .SelectEight,
    .SelectNine,
    .SelectTen,
}

InputState :: enum {
    Game,
    UI_Interact,
}

input_state: InputState = .Game

// Keys we care about
keycodes := [?]rl.KeyboardKey{.KP_7, .KP_8, .KP_9, .KP_4, .KP_5, .KP_6, .KP_1, .KP_2, .KP_3, .TAB}


poll_input :: proc() -> rl.KeyboardKey {
    for key in keycodes {
        if rl.IsKeyPressed(key) || rl.IsKeyPressedRepeat(key) {
            return key
        }
    }
    return .KEY_NULL
}

handle_input :: proc() {
    key := poll_input()

    c: InputCommand
    #partial switch key {
    case .KEY_NULL:
        return
    case .KP_1:
        c = .DownLeft
    case .KP_2:
        c = .Down
    case .KP_3:
        c = .DownRight
    case .KP_4:
        c = .Left
    case .KP_5:
        c = .Neutral
    case .KP_6:
        c = .Right
    case .KP_7:
        c = .UpLeft
    case .KP_8:
        c = .Up
    case .KP_9:
        c = .UpRight
    case .ENTER, .KP_ENTER:
        c = .Accept

    case .ONE:
        c = .SelectOne
    case .TWO:
        c = .SelectTwo
    case .THREE:
        c = .SelectThree
    case .FOUR:
        c = .SelectFour
    case .FIVE:
        c = .SelectFive
    case .SIX:
        c = .SelectSix
    case .SEVEN:
        c = .SelectSeven
    case .EIGHT:
        c = .SelectEight
    case .NINE:
        c = .SelectNine
    case .ZERO:
        c = .SelectTen

    case .W:
        c = .OpenWield

    case:
        return
    }
    run_command(c)
}


run_command :: proc(c: InputCommand) {
    #partial switch c {
    case .DownLeft:
        game.player.next_action = ActionMove{Dirs[.SouthWest]}
    case .Down:
        game.player.next_action = ActionMove{Dirs[.South]}
    case .DownRight:
        game.player.next_action = ActionMove{Dirs[.SouthEast]}
    case .Left:
        game.player.next_action = ActionMove{Dirs[.West]}
    case .Neutral:
        game.player.next_action = ActionMove{{0, 0}}
    case .Right:
        game.player.next_action = ActionMove{Dirs[.East]}
    case .UpLeft:
        game.player.next_action = ActionMove{Dirs[.NorthWest]}
    case .Up:
        game.player.next_action = ActionMove{Dirs[.North]}
    case .UpRight:
        game.player.next_action = ActionMove{Dirs[.NorthEast]}

    case:
        return
    }
}
