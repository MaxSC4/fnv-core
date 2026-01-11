INV_PERSIST = {}

local function Key(player_id)
    return "inv_" .. tostring(player_id)
end

function INV_PERSIST.Load(player_id)
    local data = Package.GetPersistentData() or {}
    local inv = data[Key(player_id)]

    if type(inv) == "table" then
        return inv
    end

    return INV.New()
end

function INV_PERSIST.Save(player_id, inv)
    Package.SetPersistentData(Key(player_id), inv)
end
