HP = {}
HP._HOT = HP._HOT or {}
HP._BOUND = HP._BOUND or {}
HP._REGEN = HP._REGEN or {}

local HEALING_RATE_TICK_MS = 60000
local GAME_HOUR_SECONDS = 3.333

local function ClampCondition(condition)
    condition = tonumber(condition)
    if condition == nil then return 100 end
    if condition < 0 then return 0 end
    if condition > 100 then return 100 end
    return condition
end

local function ArmorScaleFromCondition(condition)
    local pct = ClampCondition(condition) / 100
    local scaled = 0.66 + math.min((0.34 * pct) / 0.5, 0.34)
    return math.max(0.66, math.min(1.0, scaled))
end

local function GetEquippedArmor(state)
    if not state or not state.equipped or not state.inventory then return nil, nil end
    local inv = INV and INV.Normalize and INV.Normalize(state.inventory) or state.inventory
    if not inv or not inv.instances then return nil, nil end
    local armor_id = state.equipped.armor_body_instance_id or state.equipped.armor_head_instance_id
    if not armor_id then return nil, nil end
    local inst = inv.instances[armor_id]
    if not inst then return nil, nil end
    local def = ITEMS and ITEMS.Get and ITEMS.Get(inst.base_id)
    if not def or def.category ~= "apparel" then return nil, nil end
    return inst, def
end

local function CalcArmorDT(state)
    local inst, def = GetEquippedArmor(state)
    if not inst or not def then return 0 end
    local base = tonumber(def.dt or def.dr or 0) or 0
    if base <= 0 then return 0 end
    local scale = ArmorScaleFromCondition(inst.condition or def.cnd or 100)
    return base * scale, inst, def
end

local function SaveInventoryState(player, state)
    local player_id = PLAYERS and PLAYERS.GetID and PLAYERS.GetID(player)
    if not player_id or not state or not state.inventory then return end
    if INV_STORE and INV_STORE.Save then
        INV_STORE.Save(player_id, state.inventory)
    end
end

function HP.CalcBase(endurance, level)
    endurance = tonumber(endurance) or 5
    level = tonumber(level) or 1
    if level < 1 then level = 1 end
    return 100 + (endurance * 20) + ((level - 1) * 5)
end

local function GetHealingRate(state)
    local endu = tonumber(state and state.endurance) or 0
    if endu >= 9 then return 10 end
    if endu >= 6 then return 5 end
    return 0
end

function HP.Init(state)
    if not state then return end
    state.endurance = tonumber(state.endurance) or 5
    state.level = tonumber(state.level) or 1

    state.hp_max = HP.CalcBase(state.endurance, state.level)
    if state.hp == nil then
        state.hp = state.hp_max
    else
        if state.hp < 0 then state.hp = 0 end
        if state.hp > state.hp_max then state.hp = state.hp_max end
    end
end

function HP.HealOverTime(player, state, total, duration_ms, ticks)
    total = tonumber(total) or 0
    duration_ms = tonumber(duration_ms) or 0
    ticks = tonumber(ticks) or 0
    if total <= 0 or duration_ms <= 0 or ticks <= 0 then return false end

    local per_tick = total / ticks
    local interval = math.floor(duration_ms / ticks)
    if interval < 50 then interval = 50 end

    local key = player
    HP._HOT[key] = HP._HOT[key] or {}

    local timer_id = nil
    local count = 0
    timer_id = Timer.SetInterval(function()
        if player and player.IsValid and not player:IsValid() then
            if timer_id then Timer.ClearInterval(timer_id) end
            return
        end
        count = count + 1
        if STATE and STATE.Heal then
            STATE.Heal(state, per_tick)
        else
            state.hp = math.min((state.hp or 0) + per_tick, state.hp_max or 0)
        end
        local char = player and player.GetControlledCharacter and player:GetControlledCharacter()
        if char and char.IsValid and char:IsValid() and char.SetHealth then
            char:SetHealth(state.hp)
        end
        if HUD_SYNC and HUD_SYNC.Send and player then
            HUD_SYNC.Send(player, state)
        end
        if count >= ticks then
            if timer_id then Timer.ClearInterval(timer_id) end
        end
    end, interval)

    table.insert(HP._HOT[key], timer_id)
    return true
end

local function StopHealingRate(player)
    local entry = HP._REGEN[player]
    if not entry then return end
    if entry.timer then
        Timer.ClearInterval(entry.timer)
    end
    HP._REGEN[player] = nil
end

local function StartHealingRate(player, state)
    if not player then return end
    if HP._REGEN[player] then return end

    local entry = { last = os.clock(), accum = 0 }
    HP._REGEN[player] = entry

    entry.timer = Timer.SetInterval(function()
        if player and player.IsValid and not player:IsValid() then
            StopHealingRate(player)
            return
        end
        if not state then return end

        local rate = tonumber(state.healing_rate)
        if rate == nil then
            rate = GetHealingRate(state)
            state.healing_rate = rate
        end
        if rate <= 0 then
            entry.last = os.clock()
            return
        end
        if (state.hp or 0) >= (state.hp_max or 0) then
            entry.last = os.clock()
            return
        end

        local now = os.clock()
        local dt = now - (entry.last or now)
        if dt < 0 then dt = 0 end
        entry.last = now

        local gain = 0
        if rate >= 9 then
            gain = 2
        elseif rate >= 6 then
            gain = 1
        end
        if gain <= 0 then return end
        local whole = math.floor(gain)

        state.hp = math.min((state.hp or 0) + whole, state.hp_max or 0)
        if LOG and LOG.Info then
            LOG.Info(string.format("[HEAL] rate=%s gain=%s hp=%s/%s",
                tostring(rate),
                tostring(whole),
                tostring(state.hp),
                tostring(state.hp_max)))
        end
        if HUD_SYNC and HUD_SYNC.Send then
            HUD_SYNC.Send(player, state)
        end
        local char = player.GetControlledCharacter and player:GetControlledCharacter()
        if char and char.IsValid and char:IsValid() and char.SetHealth then
            char:SetHealth(state.hp)
        end
    end, HEALING_RATE_TICK_MS)
end

function HP.ApplyIncomingDamage(player, state, amount)
    if not state then return 0 end
    local dmg = tonumber(amount) or 0
    if dmg <= 0 then return 0 end

    local dt, armor_inst, armor_def = CalcArmorDT(state)
    local effective = dmg
    if dt and dt > 0 then
        effective = dmg - dt
        if effective < 0 then effective = 0 end
    end

    if armor_inst and dmg > (dt or 0) then
        armor_inst.condition = ClampCondition((armor_inst.condition or 100) - 0.2)
        if LOG and LOG.Info then
            LOG.Info(string.format("[CND] armor=%s instance=%s cnd=%.2f",
                tostring(armor_def and armor_def.name or armor_def and armor_def.id or "armor"),
                tostring(armor_inst.id),
                tonumber(armor_inst.condition) or 0))
        end
        local now = os.clock()
        if not state._armor_save_t or (now - state._armor_save_t) > 2.0 then
            state._armor_save_t = now
            SaveInventoryState(player, state)
        end
    end

    state.hp = math.max((state.hp or state.hp_max or 0) - effective, 0)
    local char = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if char and char.IsValid and char:IsValid() then
        if char.SetCanDie then
            char:SetCanDie((state.hp or 0) <= 0)
        end
        if char.SetMaxHealth then
            char:SetMaxHealth(state.hp_max or 100)
        end
        if char.SetHealth then
            if (state.hp or 0) <= 0 then
                char:SetHealth(0)
            else
                char:SetHealth(state.hp_max or 100)
            end
        end
    end
    if HUD_SYNC and HUD_SYNC.MarkDirty then
        HUD_SYNC.MarkDirty(state)
        if HUD_SYNC.Send then
            HUD_SYNC.Send(player, state)
        end
    end

    return effective
end

function HP.SyncCharacterHealth(player, state, character)
    local char = character or (player and player.GetControlledCharacter and player:GetControlledCharacter())
    if not char or not char.IsValid or not char:IsValid() or not state then return end
    local hp = tonumber(state.hp) or 0
    local hp_max = tonumber(state.hp_max) or 100
    if hp > hp_max then hp = hp_max end
    if hp < 0 then hp = 0 end
    if char.SetCanDie then
        char:SetCanDie(hp <= 0)
    end
    if char.SetMaxHealth then
        char:SetMaxHealth(hp_max)
    end
    if char.SetHealth then
        if hp > 0 then
            char:SetHealth(hp_max)
        else
            char:SetHealth(0)
        end
    end
end

function HP.BindCharacter(player, state, character)
    local char = character or (player and player.GetControlledCharacter and player:GetControlledCharacter())
    if not char or not char.IsValid or not char:IsValid() or not char.Subscribe then return end

    if HP._BOUND[char] then
        HP.SyncCharacterHealth(player, state, char)
        return
    end

    HP._BOUND[char] = true
    HP.SyncCharacterHealth(player, state, char)
    StartHealingRate(player, state)

    char:Subscribe("TakeDamage", function(_, amount, _, instigator)
        local st = state or (PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player))
        if not st then return end
        HP.ApplyIncomingDamage(player, st, amount)

        if char and char.IsValid and char:IsValid() and char.SetHealth then
            if char.SetCanDie then
                char:SetCanDie((st.hp or 0) <= 0)
            end
            if char.SetMaxHealth then
                char:SetMaxHealth(st.hp_max or 100)
            end
            if (st.hp or 0) <= 0 then
                char:SetHealth(0)
            else
                char:SetHealth(st.hp_max or 100)
            end
        end
    end)
end

Player.Subscribe("Destroy", function(player)
    StopHealingRate(player)
end)
