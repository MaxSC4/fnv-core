HUD_SYNC = HUD_SYNC or {}

local function ClampPct(value)
    value = tonumber(value)
    if value == nil then return nil end
    if value < 0 then return 0 end
    if value > 100 then return 100 end
    return value
end

local function Round2(value)
    if value == nil then return nil end
    return math.floor((value * 100) + 0.5) / 100
end

local function RoundInt(value)
    if value == nil then return nil end
    return math.floor(tonumber(value) + 0.5)
end

local function ArmorScaleFromCondition(condition)
    condition = tonumber(condition)
    if condition == nil then return 1 end
    if condition < 0 then condition = 0 end
    if condition > 100 then condition = 100 end
    local pct = condition / 100
    local scaled = 0.66 + math.min((0.34 * pct) / 0.5, 0.34)
    return math.max(0.66, math.min(1.0, scaled))
end

local function CalcArmorStats(state)
    if not state or not state.equipped or not state.inventory then
        return 0, 0
    end
    local inv = INV and INV.Normalize and INV.Normalize(state.inventory) or state.inventory
    if not inv or not inv.instances then return 0, 0 end

    local dt = 0
    local dr = 0

    local function AddArmor(instance_id)
        local inst = inv.instances[instance_id]
        if not inst then return end
        local def = ITEMS and ITEMS.Get and ITEMS.Get(inst.base_id)
        if not def or def.category ~= "apparel" then return end
        local scale = ArmorScaleFromCondition(inst.condition or def.cnd or 100)
        if def.dt then dt = dt + (def.dt * scale) end
        if def.dr then dr = dr + (def.dr * scale) end
    end

    AddArmor(state.equipped.armor_body_instance_id)
    AddArmor(state.equipped.armor_head_instance_id)

    return Round2(dt), Round2(dr)
end

local function GetEquippedConditions(state)
    local out = {
        equip = { armor = false, weapon = false },
        cnd = { armor_pct = nil, weapon_pct = nil }
    }

    if not state or not state.equipped or not state.inventory then
        return out
    end

    local inv = INV and INV.Normalize and INV.Normalize(state.inventory) or state.inventory
    if not inv or not inv.instances then return out end

    local weapon_id = state.equipped.weapon_instance_id
    if weapon_id and inv.instances[weapon_id] then
        local inst = inv.instances[weapon_id]
        local def = ITEMS and ITEMS.Get and ITEMS.Get(inst.base_id)
        local cnd = inst.condition or (def and def.cnd) or 100
        out.equip.weapon = true
        out.cnd.weapon_pct = ClampPct(cnd)
    end

    local armor_id = state.equipped.armor_body_instance_id or state.equipped.armor_head_instance_id
    if armor_id and inv.instances[armor_id] then
        local inst = inv.instances[armor_id]
        local def = ITEMS and ITEMS.Get and ITEMS.Get(inst.base_id)
        local cnd = inst.condition or (def and def.cnd) or 100
        out.equip.armor = true
        out.cnd.armor_pct = ClampPct(cnd)
    end

    return out
end

function HUD_SYNC.BuildState(player_state)
    local hp_max = tonumber(player_state and player_state.hp_max) or 100
    local hp = tonumber(player_state and player_state.hp)
    if hp == nil then hp = hp_max end

    local wallet = player_state and player_state.wallet

    local cnd_state = GetEquippedConditions(player_state)
    local dt, dr = CalcArmorStats(player_state)
    local pds_current = (INV and INV.CalcWeight and player_state and player_state.inventory)
        and INV.CalcWeight(player_state.inventory) or 0
    local pds_max = tonumber(player_state and player_state.carry_weight_max) or 0
    local pds_current_int = RoundInt(pds_current)
    local pds_max_int = RoundInt(pds_max)

    return {
        hp = hp,
        hp_max = hp_max,
        ap = {
            now = player_state and player_state.ap or 0,
            max = player_state and player_state.ap_max or 0
        },
        ammo = {
            now = player_state and player_state.ammo and player_state.ammo.now or 0,
            reserve = player_state and player_state.ammo and player_state.ammo.reserve or 0
        },
        equip = cnd_state.equip,
        cnd = cnd_state.cnd,
        stats = {
            pds = { current = pds_current_int, max = pds_max_int },
            dr = dr,
            dt = dt,
            xp = { now = 1000, max = 1000 }
        },

        money = {
            caps = wallet and (WALLET.Get(wallet, "caps") or 0) or 0,
            ncr = wallet and (WALLET.Get(wallet, "ncr") or 0) or 0,
            chips = wallet and (WALLET.Get(wallet, "casino_ultraluxe") or 0) or 0,
        }
    }
end


function HUD_SYNC.Send(player, player_state)
    Events.CallRemote("FNV:HUD:Sync", player, HUD_SYNC.BuildState(player_state))
end

-- Dirty flag (optionnel mais utile)
function HUD_SYNC.MarkDirty(player_state)
    player_state.__hud_dirty = true
end

function HUD_SYNC.Flush(player, player_state)
    if not player_state.__hud_dirty then
        return
    end
    player_state.__hud_dirty = false
    HUD_SYNC.Send(player, player_state)
end

function HUD_SYNC.ClampHP(state)
    local hp_max = state.hp_max or 100
    if state.hp == nil then state.hp = hp_max end
    if state.hp < 0 then state.hp = 0 end
    if state.hp > hp_max then state.hp = hp_max end
end

function HUD_SYNC.SetHP(player, state, new_hp)
    state.hp = tonumber(new_hp) or state.hp or 100
    HUD_SYNC.ClampHP(state)
    local char = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if char and char.IsValid and char:IsValid() then
        if char.SetCanDie then
            char:SetCanDie((state.hp or 0) <= 0)
        end
        if char.SetMaxHealth then
            char:SetMaxHealth(state.hp_max or 100)
        end
        if char.SetHealth then
            if (state.hp or 0) > 0 then
                char:SetHealth(state.hp_max or 100)
            else
                char:SetHealth(0)
            end
        end
    end
    HUD_SYNC.Send(player, state)
end

function HUD_SYNC.Damage(player, state, amount)
    amount = tonumber(amount) or 0
    state.hp = (state.hp or 100) - amount
    HUD_SYNC.ClampHP(state)
    local char = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if char and char.IsValid and char:IsValid() then
        if char.SetCanDie then
            char:SetCanDie((state.hp or 0) <= 0)
        end
        if char.SetMaxHealth then
            char:SetMaxHealth(state.hp_max or 100)
        end
        if char.SetHealth then
            if (state.hp or 0) > 0 then
                char:SetHealth(state.hp_max or 100)
            else
                char:SetHealth(0)
            end
        end
    end
    HUD_SYNC.Send(player, state)
end

function HUD_SYNC.Heal(player, state, amount)
    amount = tonumber(amount) or 0
    state.hp = (state.hp or 100) + amount
    HUD_SYNC.ClampHP(state)
    local char = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if char and char.IsValid and char:IsValid() then
        if char.SetCanDie then
            char:SetCanDie((state.hp or 0) <= 0)
        end
        if char.SetMaxHealth then
            char:SetMaxHealth(state.hp_max or 100)
        end
        if char.SetHealth then
            if (state.hp or 0) > 0 then
                char:SetHealth(state.hp_max or 100)
            else
                char:SetHealth(0)
            end
        end
    end
    HUD_SYNC.Send(player, state)
end

