package ruffian
import sa "core:container/small_array"

INV_MAX_SLOTS :: 10

// fuck it, infinite stacking
// INV_MAX_STACK :: 10

EquipSlot :: enum {
    None,
    Hands,
    Ring,
    Armor,
}

InventorySlot :: struct {
    item_type: ItemType,
    count: int,
}

inv_items: sa.Small_Array(INV_MAX_SLOTS, InventorySlot)

equipped_slots := #partial [EquipSlot]^Item {}


// IMPORTANT: Caller needs to handle removing the item if this proc succeeds to avoid duplication
inv_try_add_item :: proc(item_type: ItemType) -> bool {
    item := &ITEM_POOL[item_type]

    if inv_items.len >= INV_MAX_SLOTS && !item.can_stack {
        return false
    }

    if item.can_stack {
        idx, ok := inv_idx_of(item_type)

        if ok {
            inv_items.data[idx].count += 1
            return true
        }
    }
    sa.append_elem(&inv_items, InventorySlot{item_type, 1})
    return true
}

inv_remove_item :: proc(idx: int) -> bool {
    if idx < 0 || idx >= inv_items.len {
        return false
    }

    sa.ordered_remove(&inv_items, idx)

    return true
}

inv_idx_of :: proc(item_type: ItemType) -> (int, bool) {
    for i in 0 ..< inv_items.len {
        slot := sa.get_ptr(&inv_items, i)

        if slot.item_type == item_type {
            return i, true
        }
    }
    return -1, false
}


item_at_pos :: proc(p: Point) -> (Item, bool) {
    idx := p.y * MAP_WIDTH + p.x
    item, ok := game.map_items[idx]
    if !ok {
        return {}, false
    }
    return item, true
}

inv_get :: proc(slot_idx: int) -> (slot: ^InventorySlot, item: ^Item) {
    slot = sa.get_ptr(&inv_items, slot_idx)
    item = &ITEM_POOL[slot.item_type]
    return
} 

inv_set_slot :: proc(slot_idx: int, slot: InventorySlot) {
    sa.set(&inv_items, slot_idx, slot)
}

// equip_item_from_slot :: proc(slot_idx: int) -> bool {
//     slot, item := inv_get(slot_idx)    
    
//     if !item.can_equip {
//         return false
//     }

//     // Is there something already in that slot?
//     equipped_item := equipped_slots[item.slot]
    
//     equipped_slots[item.slot] = item

//     // Yes, swap the slots out
//     if equipped_item != nil {
//         inv_set_slot(slot_idx, {equippe, 1})
//     }
    
//     return true
// }


get_equip_slot_item :: proc(slot: EquipSlot) -> (it: ^Item, not_empty: bool) {
    it = equipped_slots[slot]
    return it, (it != nil)
}

equip_item_to_slot :: proc(item: ^Item, slot: EquipSlot) -> bool {
    if it := equipped_slots[slot]; it != nil {
        return false
    }

    equipped_slots[slot] = item
    on_equip(item)

    return true
}

unequip_item :: proc(slot: EquipSlot) -> (^Item, bool) {
    // this is sketchy
    item := equipped_slots[slot] 
    if item == nil do return nil, false
    equipped_slots[slot] = nil
    on_unequip(item)
    return item, true
}


on_equip :: proc(item: ^Item) {
    using game.player.stats
    ac += item.ac_bonus
    str += item.str_bonus
    agi += item.agi_bonus

    if item.slot == .Hands {
        m_atk += item.melee_damage
        r_atk += item.ranged_damage
    }
}

on_unequip :: proc(item: ^Item) {
    using game.player.stats
    ac -= item.ac_bonus
    str -= item.str_bonus
    agi -= item.agi_bonus

    if item.slot == .Hands {
        m_atk -= item.melee_damage
        r_atk -= item.ranged_damage
    }
}