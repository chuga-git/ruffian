package ruffian
import "core:fmt"
import "core:math/rand"

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
    case nil:
        return
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
        if other := entity_at(new_pos); (other != nil) && (other == game.player || entity == game.player) {
            return true, ActionAttack{other, .Melee}
        }
        entity.pos = new_pos

        if entity == game.player {
            try_pickup()
        }
        
    case ActionAttack:
        switch a.method {
        case .Melee:
            melee_attack(entity, a.target)
        case .Ranged:
            ranged_attack(entity, a.target)
        }
    // TODO multi-stage attacks return here for chaining

    case ActionRest:
        gain_hp(
            entity,
            /*TODO rest gain amount */
            1,
        )
    }

    entity.energy = 0
    entity.next_action = nil

    return true, nil
}

// FIXME: testing, temporary
PLAYER_ATK_FSTR  :: "You hit the %s for %d damage!"
MON_ATK_FSTR     :: "The %s attacks you for %d damage!"
PLAYER_MISS_FSTR :: "You miss the %s!"
MON_MISS_FSTR    :: "The %s misses you!" // TODO: proper noun formatting?
MON_DIE_FSTR     :: "You kill the %s!"
melee_attack :: proc(attacker: ^Entity, defender: ^Entity) {
    as := &attacker.stats
    ds := &defender.stats
    attack_roll := roll_d(20) + max(as.str, as.agi)

    // roll to hit
    if attack_roll < ds.ac || prob(ds.dodge) {
        if attacker == game.player {
            game_log_message(PLAYER_MISS_FSTR, defender.name)
        } else {
            game_log_message(MON_MISS_FSTR, defender.name)
        }
        return
    }

    attack_damage := as.m_atk + (max(as.str, as.agi) / 2)


    // apply damage
    ds.hp -= attack_damage

    // if defender == player: lose_game()
    if ds.hp <= 0 {
        if defender != game.player {
            game_log_message(MON_DIE_FSTR, defender.name)
        }
    } else {
        if attacker == game.player {
            game_log_message(PLAYER_ATK_FSTR, defender.name, attack_damage)
        } else {
            game_log_message(MON_ATK_FSTR, attacker.name, attack_damage)
        }
    }

}

ranged_attack :: proc(attacker: ^Entity, defender: ^Entity) {

}

// roll 1d[n]
roll_d :: proc(n: int) -> int {
    return 1 + rand.int_max(n)
}

// FIXME testing
prob :: proc(n: int) -> bool {
    return rand.int_max(100) < n
} 