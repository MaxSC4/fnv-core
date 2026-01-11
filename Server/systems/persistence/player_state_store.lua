PLAYER_STATE = {}

function PLAYER_STATE.Load(player_id)
    local core_state, created = PERSIST.LoadOrCreate(player_id)
    core_state.inventory = INV_STORE.Load(player_id)
    core_state.wallet = WALLET_STORE.Load(player_id)
    if SPECIAL and SPECIAL.Init then
        SPECIAL.Init(core_state)
    end
    if AP and AP.Init then
        AP.Init(core_state)
    end
    if HP and HP.Init then
        HP.Init(core_state)
    end
    return core_state, created
end

function PLAYER_STATE.Save(player_id, state)
    PERSIST.Save(player_id, state)
    INV_STORE.Save(player_id, state.inventory)
    WALLET_STORE.Save(player_id, state.wallet)
end
