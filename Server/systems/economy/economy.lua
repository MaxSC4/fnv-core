ECO = {}

function ECO.New()
    return { caps = 0 }
end

function ECO.Add(wallet, amount)
    if amount <= 0 then return false, "invalid_amount" end
    wallet.caps = (wallet.caps or 0) + amount
    return true
end

function ECO.CanAfford(wallet, amount)
    return (wallet.caps or 0) >= amount
end

function ECO.Spend(wallet, amount)
    if amount <= 0 then return false, "invalid_amount" end
    if not ECO.CanAfford(wallet, amount) then return false, "not_enough_caps" end
    wallet.caps = wallet.caps - amount
    return true
end
