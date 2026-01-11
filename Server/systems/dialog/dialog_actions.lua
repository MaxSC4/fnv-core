DIALOG_ACTIONS = DIALOG_ACTIONS or {}

local function Log(msg)
    if LOG and LOG.Info then
        LOG.Info("[DIALOG_ACTIONS] " .. msg)
    end
end

local function Warn(msg)
    if LOG and LOG.Warn then
        LOG.Warn("[DIALOG_ACTIONS] " .. msg)
    end
end

local function GetPlayerState(player)
    if not PLAYERS or not PLAYERS.GetState then return nil end
    return PLAYERS.GetState(player)
end

local function Notify(player, text, ms)
    if HUD_NOTIFY and HUD_NOTIFY.Send then
        HUD_NOTIFY.Send(player, text, ms)
    end
end

local function ActionOpenShop(player, option)
    local shop_id = option and option.shop_id
    if not shop_id then
        Warn("open_shop missing shop_id")
        return { refresh = false }
    end

    local shop = SHOPS and SHOPS.Get and SHOPS.Get(shop_id)
    if not shop then
        Warn("open_shop unknown shop_id=" .. tostring(shop_id))
        Notify(player, "Shop unavailable", 2000)
        return { refresh = false }
    end

    Log("open_shop shop_id=" .. tostring(shop_id))
    return { close = true, mode = "shop", shop_id = shop_id, selected = option and option.selected }
end

local function ActionGiveItem(player, option)
    local item_id = option and option.item_id
    local amount = option and option.amount or 1
    if not item_id then
        Warn("give_item missing item_id")
        return { refresh = false }
    end

    local st = GetPlayerState(player)
    if not st or not st.inventory then
        Warn("give_item missing player state")
        return { refresh = false }
    end

    local ok, err = INV.Add(st.inventory, item_id, amount)
    if not ok then
        Warn("give_item failed item=" .. tostring(item_id) .. " err=" .. tostring(err))
        Notify(player, "Cannot receive item", 2000)
        return { refresh = false }
    end

    Log("give_item item=" .. tostring(item_id) .. " x" .. tostring(amount))
    Notify(player, "Received: " .. tostring(item_id) .. " x" .. tostring(amount), 2000)
    return { refresh = true }
end

local function ActionAddMoney(player, option)
    local amount = option and option.amount or 0
    local currency = option and option.currency or "caps"
    if amount <= 0 then
        Warn("add_money invalid amount=" .. tostring(amount))
        return { refresh = false }
    end

    local st = GetPlayerState(player)
    if not st or not st.wallet then
        Warn("add_money missing player state")
        return { refresh = false }
    end

    local ok, err = WALLET.Add(st.wallet, currency, amount)
    if not ok then
        Warn("add_money failed currency=" .. tostring(currency) .. " err=" .. tostring(err))
        Notify(player, "Cannot add money", 2000)
        return { refresh = false }
    end

    Log("add_money currency=" .. tostring(currency) .. " amount=" .. tostring(amount))
    Notify(player, "Received money", 2000)
    return { refresh = true }
end

local function ActionReply(player, option)
    local text = option and (option.reply or option.text)
    if not text then
        Warn("reply missing text")
        return { refresh = false }
    end
    Notify(player, text, option and option.ms or 2500)
    return { refresh = true }
end

local function ActionSetFlag(player, option)
    local flag = option and option.flag
    if not flag then
        Warn("set_flag missing flag")
        return { refresh = false }
    end

    local st = GetPlayerState(player)
    if not st then
        Warn("set_flag missing player state")
        return { refresh = false }
    end

    st.dialog_flags = st.dialog_flags or {}
    local value = true
    if option.value ~= nil then value = option.value end
    st.dialog_flags[flag] = value

    Log("set_flag flag=" .. tostring(flag) .. " value=" .. tostring(value))
    return { refresh = true }
end

local ACTIONS = {
    open_shop = ActionOpenShop,
    give_item = ActionGiveItem,
    add_money = ActionAddMoney,
    reply = ActionReply,
    set_flag = ActionSetFlag,
}

function DIALOG_ACTIONS.Run(player, option)
    local action = option and option.action
    if not action then
        return { refresh = false }
    end

    local handler = ACTIONS[action]
    if not handler then
        Warn("unknown action=" .. tostring(action))
        return { refresh = false }
    end

    return handler(player, option) or { refresh = false }
end
