STATE = {}

function STATE.Damage(state, amount)
    state.hp = math.max((state.hp or 100) - amount, 0)
    HUD_SYNC.MarkDirty(state)
end

function STATE.Heal(state, amount)
    state.hp = math.min((state.hp or 100) + amount, state.hp_max or 100)
    HUD_SYNC.MarkDirty(state)
end

function STATE.GiveMoney(state, currency, amount)
    WALLET.Add(state.wallet, currency, amount)
    HUD_SYNC.MarkDirty(state)
end

function STATE.TakeMoney(state, currency, amount)
    local ok = WALLET.Spend(state.wallet, currency, amount)
    if ok then HUD_SYNC.MarkDirty(state) end
    return ok
end

function STATE.CanSpendAP(state, amount)
    if not AP or not AP.CanSpend then return true end
    return AP.CanSpend(state, amount)
end

function STATE.SpendAP(player, state, amount)
    if not AP or not AP.Spend then return true end
    local ok = AP.Spend(state, amount)
    if ok and HUD_SYNC and HUD_SYNC.Send then
        HUD_SYNC.Send(player, state)
    end
    return ok
end
