package ruffian
import "core:math/rand"
import "core:mem"
import rl "vendor:raylib"
EntityType :: enum {
    Player,
    Troll,
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
        stats = {hp = 20, max_hp = 20, ac = 5, dodge = 25, m_atk = 3, str = 7, agi = 2, fort = 6, intl = 1, wil = 1},
    },
}

init_player :: proc() {
    // this sucks!
    append(&game.entities, Entity{})
    game.player = &game.entities[len(game.entities) - 1]

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
    append(&game.entities, Entity{})
    new_monster = &game.entities[len(game.entities) - 1]

    mem.copy(new_monster, &ENT_POOL[type], size_of(Entity))

    new_monster.pos = position
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
    for &e in game.entities {
        if e.pos == pos {
            return &e
        }
    }
    return nil
}
