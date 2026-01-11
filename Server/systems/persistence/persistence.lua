PERSIST = {}

local function Key(player_id)
    return "player_" .. tostring(player_id)
end

function PERSIST.LoadOrCreate(player_id)
    local data = Package.GetPersistentData() or {}
    local row = data[Key(player_id)]

    if type(row) == "table" then
        local strength = tonumber(row.strength) or 5
        local perception = tonumber(row.perception) or 5
        local endurance = tonumber(row.endurance) or 5
        local charisma = tonumber(row.charisma) or 5
        local intelligence = tonumber(row.intelligence) or 5
        local agility = tonumber(row.agility) or 5
        local luck = tonumber(row.luck) or 5
        local level = tonumber(row.level) or 1
        local ap_max = (AP and AP.CalcBase and AP.CalcBase(agility)) or math.min(65 + (3 * agility), 95)
        local ap = tonumber(row.ap)
        if ap == nil then ap = ap_max end
        local hp_max = (HP and HP.CalcBase and HP.CalcBase(endurance, level)) or (100 + (endurance * 20) + ((level - 1) * 5))
        local hp = tonumber(row.hp)
        if hp == nil then hp = hp_max end
        return {
            player_id = tostring(player_id),
            last_seen = row.last_seen or os.time(),
            pos = Vector(row.pos_x or 1400, row.pos_y or 800, row.pos_z or 300),
            strength = strength,
            perception = perception,
            agility = agility,
            endurance = endurance,
            charisma = charisma,
            intelligence = intelligence,
            luck = luck,
            level = level,
            ap_max = ap_max,
            ap = ap,
            hp_max = hp_max,
            hp = hp
        }, false
    end

    local strength = 5
    local perception = 5
    local endurance = 5
    local charisma = 5
    local intelligence = 5
    local agility = 5
    local luck = 5
    local level = 1
    local ap_max = (AP and AP.CalcBase and AP.CalcBase(agility)) or math.min(65 + (3 * agility), 95)
    local hp_max = (HP and HP.CalcBase and HP.CalcBase(endurance, level)) or (100 + (endurance * 20) + ((level - 1) * 5))
    local state = {
        player_id = tostring(player_id),
        last_seen = os.time(),
        pos = Vector(1400, 800, 300),
        strength = strength,
        perception = perception,
        agility = agility,
        endurance = endurance,
        charisma = charisma,
        intelligence = intelligence,
        luck = luck,
        level = level,
        ap_max = ap_max,
        ap = ap_max,
        hp_max = hp_max,
        hp = hp_max
    }

    PERSIST.Save(player_id, state)
    return state, true
end

function PERSIST.Save(player_id, state)
    Package.SetPersistentData(Key(player_id), {
        last_seen = state.last_seen or os.time(),
        pos_x = state.pos.X,
        pos_y = state.pos.Y,
        pos_z = state.pos.Z,
        strength = state.strength or 5,
        perception = state.perception or 5,
        agility = state.agility or 5,
        ap = state.ap or state.ap_max or 0,
        endurance = state.endurance or 5,
        charisma = state.charisma or 5,
        intelligence = state.intelligence or 5,
        luck = state.luck or 5,
        level = state.level or 1,
        hp = state.hp or state.hp_max or 0
    })
end
