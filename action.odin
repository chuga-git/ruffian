package ruffian
import "core:fmt"

ActionMove :: struct {
    dir: Point,
}

ActionRest :: struct {}

ActionAttack :: struct {
    target: ^Entity,
    method: enum {
        Melee,
        Ranged,
    },
}

Action :: union {
    ActionMove,
    ActionAttack,
    ActionRest,
}


do_action :: proc(entity: ^Entity) -> (success: bool, alternate: Action) {
    success = false
    alternate = nil
    switch a in entity.next_action {
        case nil: return
        case ActionMove:
            new_pos := entity.pos + a.dir

            if a.dir == {0, 0} {
                return true, ActionRest{}
            }

            // TODO: Will need to stuff into a can_move() proc eventually
            if !in_bounds(new_pos) || get_tile_type(new_pos) == TileType.Wall {
                return
            }

            // hack for now so that monsters don't attack each other
            if other := entity_at(new_pos); other != nil && (other == game.player || entity == game.player) {
                return true, ActionAttack{other, .Melee}
            }
            entity.pos = new_pos

        case ActionAttack:
            switch a.method {
                case .Melee: melee_attack(entity, a.target)
                case .Ranged: ranged_attack(entity, a.target)
            }
            // TODO multi-stage attacks return here for chaining

        case ActionRest: 
            gain_hp(entity, /*TODO rest gain amount */ 1)
    }

    entity.energy = 0
    entity.next_action = nil

    return true, nil
}

melee_attack :: proc(attacker: ^Entity, defender: ^Entity) {
    game_log_message("Attack! Attacker: %v, Defender: %v", attacker.name, defender.name)
}

ranged_attack :: proc(attacker: ^Entity, defender: ^Entity) {

}


// battle :: proc(attacker: ^Entity, defender: ^Entity) {
//     defender.stats.hp -= 5
//     fmt.println("Battle: ", attacker, defender)
//     if defender.stats.hp <= 0 {
//         if defender != game.player {
//             idx := index_of(&game.entities, defender^)
//             if idx != -1 {
//                 ordered_remove(&game.entities, idx)
//             }
//         }
//     }
// }