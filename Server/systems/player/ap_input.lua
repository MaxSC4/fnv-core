AP_INPUT = AP_INPUT or {}
AP_INPUT.SPRINT = AP_INPUT.SPRINT or {}
AP_INPUT.SPRINT_LOCKED = AP_INPUT.SPRINT_LOCKED or {}

local SPRINT_COST_PER_SEC = 25
local SPRINT_TICK_MS = 250
local PUNCH_COST = 25

local function Now()
    return os.clock()
end

local function SpendAP(player, state, amount)
    if STATE and STATE.SpendAP then
        local ok = STATE.SpendAP(player, state, amount)
        if ok and LOG and LOG.Info then
            LOG.Info("[AP] spend player=" .. tostring(PLAYERS.GetID(player)) ..
                " amount=" .. string.format("%.2f", amount) ..
                " ap=" .. string.format("%.2f", state.ap or 0) ..
                "/" .. tostring(state.ap_max or 0))
        end
        return ok
    end
    if AP and AP.Spend then
        local ok = AP.Spend(state, amount)
        if ok and HUD_SYNC and HUD_SYNC.Send then
            HUD_SYNC.Send(player, state)
        end
        if ok and LOG and LOG.Info then
            LOG.Info("[AP] spend player=" .. tostring(PLAYERS.GetID(player)) ..
                " amount=" .. string.format("%.2f", amount) ..
                " ap=" .. string.format("%.2f", state.ap or 0) ..
                "/" .. tostring(state.ap_max or 0))
        end
        return ok
    end
    return false
end

local function SetSprintAllowed(player, allowed)
    local char = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if char and char.IsValid and char:IsValid() then
        if char.SetCanSprint then
            char:SetCanSprint(allowed)
        end
    end
end

local function SendSprintLock(player, locked)
    Events.CallRemote("FNV:AP:SprintLock", player, { locked = locked })
end

local function SpendAPPartial(player, state, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end
    if not state or state.ap == nil then return false end
    if state.ap >= amount then
        return SpendAP(player, state, amount)
    end

    if state.ap > 0 then
        local spent = state.ap
        state.ap = 0
        if HUD_SYNC and HUD_SYNC.Send then
            HUD_SYNC.Send(player, state)
        end
        AP_INPUT.SPRINT_LOCKED[player] = true
        SetSprintAllowed(player, false)
        SendSprintLock(player, true)
        if AP_INPUT.SPRINT[player] then
            AP_INPUT.SPRINT[player].active = false
        end
        if LOG and LOG.Info then
            LOG.Info("[AP] spend player=" .. tostring(PLAYERS.GetID(player)) ..
                " amount=" .. string.format("%.2f", spent) ..
                " ap=0/" .. tostring(state.ap_max or 0))
        end
        return true
    end

    return false
end

local function HandleSprintLock(player, state)
    if not state or not state.ap_max then return end
    local locked = AP_INPUT.SPRINT_LOCKED[player] == true
    if not locked and (state.ap or 0) <= 0 then
        AP_INPUT.SPRINT_LOCKED[player] = true
        SetSprintAllowed(player, false)
        SendSprintLock(player, true)
        if HUD_NOTIFY and HUD_NOTIFY.Send then
            HUD_NOTIFY.Send(player, "AP trop bas (sprint bloque)", 2000)
        end
    elseif locked then
        local threshold = (state.ap_max or 0) * 0.20
        if (state.ap or 0) >= threshold then
            AP_INPUT.SPRINT_LOCKED[player] = false
            SetSprintAllowed(player, true)
            SendSprintLock(player, false)
        end
    end
end

local function StartSprintTick()
    if AP_INPUT._timer then return end
    AP_INPUT._timer = Timer.SetInterval(function()
        local now = Now()
        for player, data in pairs(AP_INPUT.SPRINT) do
            if not player or (player.IsValid and not player:IsValid()) then
                AP_INPUT.SPRINT[player] = nil
                AP_INPUT.SPRINT_LOCKED[player] = nil
            else
                local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
                if state then
                    HandleSprintLock(player, state)
                    if data.active and not AP_INPUT.SPRINT_LOCKED[player] then
                        local last = data.last or now
                        local dt = now - last
                        if dt > 0 then
                            local cost = SPRINT_COST_PER_SEC * dt
                            SpendAPPartial(player, state, cost)
                        end
                        data.last = now
                    else
                        data.last = now
                    end
                end
            end
        end
    end, SPRINT_TICK_MS)
end

Events.SubscribeRemote("FNV:AP:Sprint", function(player, payload)
    if not player then return end
    if AP_INPUT.SPRINT_LOCKED[player] then
        return
    end
    local active = payload and payload.active == true
    AP_INPUT.SPRINT[player] = AP_INPUT.SPRINT[player] or { active = false, last = Now() }
    AP_INPUT.SPRINT[player].active = active
    AP_INPUT.SPRINT[player].last = Now()
end)

Events.SubscribeRemote("FNV:AP:Punch", function(player, payload)
    if not player then return end
    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state then return end
    SpendAP(player, state, PUNCH_COST)
end)

Player.Subscribe("Destroy", function(player)
    AP_INPUT.SPRINT[player] = nil
    AP_INPUT.SPRINT_LOCKED[player] = nil
end)

StartSprintTick()
