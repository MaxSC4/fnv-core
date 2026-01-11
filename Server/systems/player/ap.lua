AP = AP or {}

local BASE_AP = 65
local AGI_MULT = 3
local BASE_CAP = 95
local REGEN_SECONDS = 16.66
local TICK_MS = 250

local function CalcBase(agility)
    local agi = tonumber(agility) or 0
    local ap = BASE_AP + (AGI_MULT * agi)
    if ap > BASE_CAP then ap = BASE_CAP end
    return ap
end

local function Now()
    return os.clock()
end

local function Sync(player, state)
    if HUD_SYNC and HUD_SYNC.Send then
        HUD_SYNC.Send(player, state)
    end
end

function AP.CalcBase(agility)
    return CalcBase(agility)
end

function AP.Init(state)
    if not state then return end

    if state.agility == nil then
        state.agility = 5
    end

    state.ap_max = CalcBase(state.agility)
    if state.ap == nil then
        state.ap = state.ap_max
    end

    if state.ap > state.ap_max then state.ap = state.ap_max end
    if state.ap < 0 then state.ap = 0 end

    state._ap_last_update = Now()
end

function AP.SetAgility(state, agility)
    if not state then return end
    state.agility = tonumber(agility) or state.agility or 0
    local prev_max = state.ap_max or 0
    state.ap_max = CalcBase(state.agility)
    if state.ap == nil then state.ap = state.ap_max end
    if state.ap > state.ap_max then state.ap = state.ap_max end

    if state.ap_max ~= prev_max then
        state._ap_last_update = Now()
    end
end

function AP.CanSpend(state, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end
    return (state and state.ap or 0) >= amount
end

function AP.Spend(state, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end
    if not AP.CanSpend(state, amount) then
        return false
    end
    state.ap = (state.ap or 0) - amount
    if state.ap < 0 then state.ap = 0 end
    return true
end

function AP.Regen(state, dt)
    if not state or not state.ap_max then return false end
    if state.ap == nil then state.ap = state.ap_max end
    if state.ap >= state.ap_max then return false end

    local rate = state.ap_max / REGEN_SECONDS
    local add = rate * dt
    if add <= 0 then return false end
    state.ap = math.min(state.ap_max, state.ap + add)
    return true
end

function AP.Start()
    if AP._timer then return end
    AP._timer = Timer.SetInterval(function()
        local now = Now()
        for _, player in pairs(Player.GetAll()) do
            local state = PLAYERS.GetState(player)
            if state and state.ap_max then
                local last = state._ap_last_update or now
                local dt = now - last
                if dt > 0 then
                    local changed = AP.Regen(state, dt)
                    if changed then
                        Sync(player, state)
                    end
                end
                state._ap_last_update = now
            end
        end
    end, TICK_MS)
end
