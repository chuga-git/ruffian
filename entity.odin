package ruffian
import "core:math/rand"
import "core:mem"
import rl "vendor:raylib"
EntityType :: enum {
    Player,
    Troll,
    Orc,
    Kestrel,
}

Entity :: struct {
    name:        string,
    kind:        EntityType,
    pos:         Point,
    last_pos:    Point,
    glyph:       Glyph,
    energy:      int,
    stats:       Stats,
    next_action: Action,
}

// Initializes to everything but the player kind
MONSTER_TYPES := ~bit_set[EntityType] {.Player}

ENT_POOL := [EntityType]Entity {
    .Player = {
        name = "Ruffian",
        kind = .Player,
        glyph = {int('@'), rl.YELLOW, rl.BLACK},
        stats = {hp = 10, str = 5, agi = 5, fort = 5, intl = 5, wil = 5},
    },
    .Troll = {
        name = "Troll",
        kind = .Troll,
        glyph = {int('T'), rl.DARKBLUE, rl.RAYWHITE},
        stats = {hp = 20, max_hp = 20, ac = 5, dodge = 0, m_atk = 3, str = 9, agi = 2, fort = 8, intl = 1, wil = 2},
    },
    .Orc = {
        name = "Orc",
        kind = .Orc,
        glyph = {int('O'), rl.GREEN, rl.DARKGREEN},
        stats = {hp = 10, max_hp = 20, ac = 10, dodge = 5, m_atk = 3, str = 5, agi = 3, fort = 6, intl = 3, wil = 3},
    },
    .Kestrel = {
        name = "Kestrel",
        kind = .Kestrel,
        glyph = {int('K'), rl.BROWN, rl.DARKBROWN},
        stats = {hp = 15, max_hp = 15, ac = 5, dodge = 25, m_atk = 2, str = 3, agi = 8, fort = 4, intl = 0, wil = 2},
    }
}

init_player :: proc() {
    // this sucks!
    game.player = new(Entity)
    append(&game.entities, game.player)
    // this sucks too!
    mem.copy(game.player, &ENT_POOL[.Player], size_of(Entity))

    game.player.pos = rand_point_on_map()

    // starting equipment
    equip_item_to_slot(&ITEM_POOL[.Armor_Chain], .Armor)
    equip_item_to_slot(&ITEM_POOL[.Weapon_Mace], .Hands)

    // 5 bread
    for i in 0 ..< 5 {
        inv_try_add_item(.Food_Bread)
    }

    // calculate stats
    update_player_stats()
    game.player.stats.hp = game.player.stats.max_hp
}

make_monster_at :: proc(type: EntityType, position: Point) -> (new_monster: ^Entity) {
    mon := new(Entity)
    append(&game.entities, mon)
    mem.copy(mon, &ENT_POOL[type], size_of(Entity))
    mon.pos = position
    return
}

make_monster_rand :: proc(type: EntityType) -> (new_monster: ^Entity) {
    return make_monster_at(type, rand_point_on_map())
}

make_monster :: proc {
    make_monster_at,
    make_monster_rand,
}

entity_at :: proc(pos: Point) -> ^Entity {
    for e in game.entities {
        if e.pos == pos {
            return e
        }
    }
    return nil
}
