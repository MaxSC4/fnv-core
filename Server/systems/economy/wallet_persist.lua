WALLET_PERSIST = {}

local function Key(player_id)
    return "wallet_" .. tostring(player_id)
end

function WALLET_PERSIST.Load(player_id)
    local data = Package.GetPersistentData() or {}
    local wallet = data[Key(player_id)]

    if type(wallet) == "table" then
        return wallet
    end

    return WALLET.New()
end

function WALLET_PERSIST.Save(player_id, wallet)
    Package.SetPersistentData(Key(player_id), wallet)
end
