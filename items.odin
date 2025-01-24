package ruffian


ItemType :: enum {
    Weapon_Mace,
    Armor_Chain,
    Ring_Strength,
    Food_Bread,
}


Item :: struct {
    name:          string,

    // can count be > 1?
    can_stack:     bool,
    can_equip:     bool,
    can_eat:       bool,
    slot:          EquipSlot,

    // damage bonus when used during melee attack
    melee_damage:  int,

    // damage bonus when thrown (via bow or otherwise)
    ranged_damage: int,

    // ability bonuses
    ac_bonus:      int,
    str_bonus:     int,
    agi_bonus:     int,

    // TODO: implement these 
    // int_bonus: int,
    // for_bonus: int,
    // wil_bonus: int,
    // dodge_bonus: int,
}

ITEM_POOL := [ItemType]Item {
    .Weapon_Mace = {name = "Mace", can_equip = true, slot = .Hands, melee_damage = 5},
    .Armor_Chain = {name = "Chainmail Armor", can_equip = true, slot = .Armor, ac_bonus = 5},
    .Ring_Strength = {name = "Ring of Strength", can_equip = true, slot = .Ring, str_bonus = 1},
    .Food_Bread = {name = "Bread", can_stack = true, can_eat = true},
}

item_pool_get :: proc(type: ItemType) -> ^Item {
    return &ITEM_POOL[type]
}
