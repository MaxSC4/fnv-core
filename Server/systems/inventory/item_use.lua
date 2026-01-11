ITEM_USE = {}

local function ApplyUseEffect(player_state, def, player)
    local hp_max = player_state.hp_max or 100
    if def.use and def.use.type == "heal" then
        local amount = tonumber(def.use.amount) or 0
        if STATE and STATE.Heal then
            STATE.Heal(player_state, amount)
        else
            player_state.hp = math.min(
                (player_state.hp or 100) + amount,
                hp_max
            )
        end
        return true, "healed_" .. tostring(amount)
    end

    if def.use and def.use.type == "heal_pct" then
        local pct = tonumber(def.use.pct) or 0
        local amount = math.floor((hp_max * pct) + 0.5)
        local duration = tonumber(def.use.duration) or 0
        local ticks = tonumber(def.use.ticks) or 0
        if duration > 0 and ticks > 0 and HP and HP.HealOverTime and player then
            HP.HealOverTime(player, player_state, amount, math.floor(duration * 1000), ticks)
        else
            if STATE and STATE.Heal then
                STATE.Heal(player_state, amount)
            else
                player_state.hp = math.min(
                    (player_state.hp or 100) + amount,
                    hp_max
                )
            end
        end
        return true, "healed_" .. tostring(amount)
    end
    return true, "used"
end

function ITEM_USE.Use(player_state, item_id, instance_id, player)
    local inv = player_state.inventory
    if not inv then return false, "no_inventory" end

    local def = ITEMS.Get(item_id)
    if not def then
        return false, "unknown_item"
    end

    if def.use and def.use.type == "repair_kit" then
        local equip = player_state.equipped or {}
        local target_id = equip.weapon_instance_id or equip.armor_body_instance_id or equip.armor_head_instance_id
        if not target_id or not inv.instances or not inv.instances[target_id] then
            return false, "no_repair_target"
        end
        local target = inv.instances[target_id]
        local ok, reason = false, "repair_failed"
        if INV_SERVICE and INV_SERVICE.RepairItem then
            ok, reason = INV_SERVICE.RepairItem(player, player_state, target.base_id, target_id, "kit_only")
        end
        if not ok then
            return false, reason
        end
        return true, "repaired", { target_id = target.base_id, target_instance_id = target_id }
    end

    if instance_id then
        if not INV.HasInstance(inv, instance_id, item_id) then
            return false, "not_owned"
        end
        local ok = INV.Remove(inv, item_id, 1, instance_id)
        if not ok then return false, "remove_failed" end
        return ApplyUseEffect(player_state, def, player)
    end

    if INV.Count(inv, item_id) <= 0 then
        return false, "not_owned"
    end

    local ok = INV.Remove(inv, item_id, 1)
    if not ok then
        return false, "remove_failed"
    end

    return ApplyUseEffect(player_state, def, player)
end
