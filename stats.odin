package ruffian


Stats :: struct {
    hp: int, // 0-999
    max_hp: int, // 0-999
    ac: int, // rest: 0-99
    dodge: int,

    m_atk: int,
    r_atk: int,

    str: int,
    agi: int,
    fort: int,
    intl: int,
    wil: int
}

gain_hp :: proc(e: ^Entity, amount: int) {

}

update_player_stats :: proc() {
    s := &game.player.stats

    s.max_hp = 1 + 2*s.fort
    s.dodge = s.agi
}