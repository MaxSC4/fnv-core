ECO_PERSIST = {}

local function Key(player_id)
    return "wallet_" .. tostring(player_id)
end

function ECO_PERSIST.Load(player_id)
    local data = Package.GetPersistentData() or {}
    local raw = data[Key(player_id)]

    if raw and type(raw) == "string" then
        local decoded = JSON.parse(raw)
        if type(decoded) == "table" and type(decoded.caps) == "number" then
            return { caps = decoded.caps }
        end
    end

    return ECO.New()
end

function ECO_PERSIST.Save(player_id, wallet)
    Package.SetPersistentData(Key(player_id), JSON.stringify({ caps = wallet.caps or 0 }))
end
