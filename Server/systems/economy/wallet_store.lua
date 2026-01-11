WALLET_STORE = {}

local function Key(player_id)
    return "wallet_" .. tostring(player_id)
end

function WALLET_STORE.Load(player_id)
    local w = PDATA.Get(Key(player_id))
    if type(w) == "table" then
        return w
    end
    return WALLET.New()
end

function WALLET_STORE.Save(player_id, wallet)
    PDATA.Set(Key(player_id), wallet)
end
