WALLET = {}

function WALLET.New()
    return {}
end

function WALLET.Get(wallet, currency)
    return wallet[currency] or 0
end

function WALLET.Add(wallet, currency, amount)
    if amount <= 0 then return false, "invalid_amount" end
    if not CURRENCIES.Get(currency) then return false, "unknown_currency" end

    wallet[currency] = (wallet[currency] or 0) + amount
    return true
end

function WALLET.CanAfford(wallet, currency, amount)
    return WALLET.Get(wallet, currency) >= amount
end

function WALLET.Spend(wallet, currency, amount)
    if amount <= 0 then return false, "invalid_amount" end
    if not WALLET.CanAfford(wallet, currency, amount) then
        return false, "not_enough_funds"
    end

    wallet[currency] = wallet[currency] - amount
    return true
end
