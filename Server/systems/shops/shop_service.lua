SHOP = {}
SHOP.SESSIONS = SHOP.SESSIONS or {}

local function Round2(value)
    if value == nil then return nil end
    return math.floor((value * 100) + 0.5) / 100
end

local function RoundInt(value)
    if value == nil then return nil end
    return math.floor(tonumber(value) + 0.5)
end

local function CalcDps(def)
    if not def or not def.weapon then return nil end
    local damage = tonumber(def.weapon.damage)
    local cadence = tonumber(def.weapon.cadence)
    if not damage or not cadence or cadence <= 0 then return nil end
    return Round2(damage / cadence)
end

local function CalcVw(value, weight)
    value = tonumber(value)
    weight = tonumber(weight)
    if not value or not weight or weight <= 0 then return nil end
    return Round2(value / weight)
end

local function Log(msg)
    if LOG and LOG.Info then
        LOG.Info("[SHOP] " .. msg)
    end
end

local function Warn(msg)
    if LOG and LOG.Warn then
        LOG.Warn("[SHOP] " .. msg)
    end
end

local function SendOpen(player, payload)
    Events.CallRemote("FNV:Shop:Open", player, payload)
end

local function SendClose(player)
    Events.CallRemote("FNV:Shop:Close", player, { open = false })
end

local function SetMode(player, mode)
    Events.CallRemote("FNV:UI:SetMode", player, { mode = mode })
end

local function FreezePlayerForShop(player, freeze)
    local char = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if not char or not char.IsValid or not char:IsValid() then return end
    if char.SetInputEnabled then
        char:SetInputEnabled(not freeze)
    end
end

local function GetCurrencyLabel(currency_id)
    local cur = CURRENCIES and CURRENCIES.Get and CURRENCIES.Get(currency_id)
    if cur and cur.name then return cur.name end
    return currency_id
end

local function GetPriceModifiers(shop)
    local mods = shop.price_modifiers or {}
    return {
        buy_mult = tonumber(mods.buy_mult) or 1.0,
        sell_mult = tonumber(mods.sell_mult) or 1.0,
        barter = tonumber(mods.barter) or 0,
        reputation = tonumber(mods.reputation) or 0
    }
end

local function IsStackable(def)
    return def and def.max_stack and def.max_stack > 1
end

local function CanAddToInventory(inv, item_id, qty)
    local def = ITEMS and ITEMS.Get and ITEMS.Get(item_id)
    if not def then return false, "unknown_item" end
    if IsStackable(def) then
        local current = INV.Count(inv, item_id)
        local max_stack = def.max_stack or 999999
        if current + qty > max_stack then
            return false, "stack_limit"
        end
    end
    return true
end

local function GetStockEntry(shop, item_id)
    if not shop or not shop.stock then return nil end
    return shop.stock[item_id]
end

local function GetStockQty(shop, item_id)
    local entry = GetStockEntry(shop, item_id)
    if type(entry) == "table" then
        return tonumber(entry.qty) or 0
    end
    return tonumber(entry) or 0
end

local function GetStockCondition(shop, item_id)
    local entry = GetStockEntry(shop, item_id)
    if type(entry) == "table" then
        return entry.cnd
    end
    return nil
end

local function SetStockQty(shop, item_id, qty)
    if not shop or not shop.stock then return end
    local entry = shop.stock[item_id]
    if type(entry) == "table" then
        entry.qty = qty
    else
        shop.stock[item_id] = qty
    end
end

local function CalcUnitPrice(base_price, mult)
    if not base_price then return nil end
    return math.max(1, math.floor((base_price * mult) + 0.5))
end

local function CalcConditionedPrice(base_price, condition, mult, def)
    if not base_price then return nil end
    local value = base_price
    if condition ~= nil and INV and INV.CalcValue then
        local scaled = INV.CalcValue(def, condition)
        if scaled ~= nil then
            value = scaled
        end
    end
    return CalcUnitPrice(value, mult)
end

local function BuildVendorInventory(shop, mods)
    local list = {}
    for item_id, base_price in pairs(shop.buy or {}) do
        local def = ITEMS and ITEMS.Get and ITEMS.Get(item_id)
        local stock_qty = GetStockQty(shop, item_id)
        local stock_cnd = GetStockCondition(shop, item_id)
        local unit = CalcConditionedPrice(base_price, stock_cnd, mods.buy_mult, def)
        local weight = def and def.wg or 0
        local weight_int = RoundInt(weight)
        local dps = CalcDps(def)
        local vw = CalcVw(unit, weight)
        list[#list + 1] = {
            item_id = item_id,
            name = def and def.name or item_id,
            desc = def and def.desc or nil,
            icon = def and def.icon or nil,
            item_icon = def and (def.item_icon or def.icon) or nil,
            wg = weight_int,
            cnd = stock_cnd ~= nil and stock_cnd or (def and def.cnd or nil),
            qty = stock_qty,
            stackable = IsStackable(def),
            max_stack = def and def.max_stack or nil,
            base_value = base_price,
            unit_price = unit,
            dps = dps,
            vw = vw,
            str = def and def.str or nil,
            deg = def and def.weapon and def.weapon.damage or nil,
            pds = weight_int,
            val = unit,
            ammo_type = def and def.ammo_type or nil,
            effects = def and def.effects or {}
        }
    end
    return list
end

local function BuildPlayerInventory(state, shop, mods)
    local list = {}
    local inv = INV and INV.Normalize and INV.Normalize(state.inventory) or state.inventory
    local entries = INV and INV.GetEntries and INV.GetEntries(inv) or {}

    for _, entry in ipairs(entries) do
        local item_id = entry.base_id
        local def = ITEMS and ITEMS.Get and ITEMS.Get(item_id)
        local base_price = shop.sell and shop.sell[item_id]
        local unit = CalcConditionedPrice(base_price, entry.condition, mods.sell_mult, def)
        local weight = def and def.wg or 0
        local weight_int = RoundInt(weight)
        local dps = CalcDps(def)
        local vw = CalcVw(unit, weight)
        list[#list + 1] = {
            item_id = item_id,
            instance_id = entry.instance_id,
            name = def and def.name or item_id,
            desc = def and def.desc or nil,
            icon = def and def.icon or nil,
            item_icon = def and (def.item_icon or def.icon) or nil,
            wg = weight_int,
            cnd = entry.condition or (def and def.cnd or nil),
            qty = entry.qty or 1,
            stackable = entry.stackable ~= false,
            max_stack = def and def.max_stack or nil,
            base_value = base_price,
            unit_price = unit,
            can_sell = base_price ~= nil,
            dps = dps,
            vw = vw,
            str = def and def.str or nil,
            deg = def and def.weapon and def.weapon.damage or nil,
            pds = weight_int,
            val = unit,
            ammo_type = def and def.ammo_type or nil,
            effects = def and def.effects or {}
        }
    end
    return list
end

local function ComputeTotals(cart_buy, cart_sell, shop, mods)
    local total_buy = 0
    local total_sell = 0

    for item_id, qty in pairs(cart_buy or {}) do
        if qty > 0 then
            local base = shop.buy and shop.buy[item_id]
            local unit = CalcUnitPrice(base, mods.buy_mult)
            if unit then total_buy = total_buy + (unit * qty) end
        end
    end

    for item_id, qty in pairs(cart_sell or {}) do
        if qty > 0 then
            local base = shop.sell and shop.sell[item_id]
            local unit = CalcUnitPrice(base, mods.sell_mult)
            if unit then total_sell = total_sell + (unit * qty) end
        end
    end

    return total_buy, total_sell, (total_buy - total_sell)
end

local function BuildCartList(cart, shop, mods, side)
    local out = {}
    for item_id, qty in pairs(cart or {}) do
        if qty > 0 then
            local base = (side == "buy") and (shop.buy and shop.buy[item_id]) or (shop.sell and shop.sell[item_id])
            local mult = (side == "buy") and mods.buy_mult or mods.sell_mult
            local def = ITEMS and ITEMS.Get and ITEMS.Get(item_id)
            local unit = CalcConditionedPrice(base, (side == "buy") and GetStockCondition(shop, item_id) or nil, mult, def)
            local weight = def and def.wg or 0
            local weight_int = RoundInt(weight)
            local dps = CalcDps(def)
            local vw = CalcVw(unit, weight)
            out[#out + 1] = {
                item_id = item_id,
                name = def and def.name or item_id,
                icon = def and def.icon or nil,
                qty = qty,
                unit_price = unit,
                cnd = (side == "buy") and (GetStockCondition(shop, item_id) or (def and def.cnd or nil)) or (def and def.cnd or nil),
                item_icon = def and (def.item_icon or def.icon) or nil,
                dps = dps,
                vw = vw,
                str = def and def.str or nil,
                deg = def and def.weapon and def.weapon.damage or nil,
                pds = weight_int,
                val = unit,
                ammo_type = def and def.ammo_type or nil,
                effects = def and def.effects or {}
            }
        end
    end
    return out
end

local function BuildSnapshot(player, session)
    local shop = SHOPS and SHOPS.Get and SHOPS.Get(session.shop_id)
    if not shop then return nil end

    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state or not state.wallet or not state.inventory then return nil end

    local currency_id = shop.currency or "caps"
    local player_caps = WALLET and WALLET.Get and WALLET.Get(state.wallet, currency_id) or 0
    local vendor_caps = session.vendor_caps or shop.caps or 9999
    local mods = GetPriceModifiers(shop)

    local total_buy, total_sell, delta = ComputeTotals(session.cart_buy, session.cart_sell, shop, mods)
    local can_accept = true
    local reason = nil
    if delta > player_caps then
        can_accept = false
        reason = "not_enough_player_caps"
    elseif delta < 0 and math.abs(delta) > vendor_caps then
        can_accept = false
        reason = "not_enough_vendor_caps"
    end

    return {
        open = true,
        vendor = {
            id = session.shop_id,
            name = shop.name or session.shop_id,
            caps = vendor_caps
        },
        player = {
            caps = player_caps
        },
        currency = {
            id = currency_id,
            name = GetCurrencyLabel(currency_id)
        },
        price_modifiers = mods,
        vendor_inventory = BuildVendorInventory(shop, mods),
        player_inventory = BuildPlayerInventory(state, shop, mods),
        cart_buy = BuildCartList(session.cart_buy, shop, mods, "buy"),
        cart_sell = BuildCartList(session.cart_sell, shop, mods, "sell"),
        totals = {
            buy = total_buy,
            sell = total_sell,
            delta = delta
        },
        last_tx = session.last_tx,
        can_accept = can_accept,
        reason = reason,
        can_close = true
    }
end

local function ResetCart(session)
    session.cart_buy = {}
    session.cart_sell = {}
end

local function ParseCartSnapshot(payload)
    local buy = {}
    local sell = {}

    if payload and payload.cart_buy then
        for _, line in ipairs(payload.cart_buy) do
            local item_id = line.item_id or line.id
            local qty = tonumber(line.qty) or 0
            if item_id and qty > 0 then
                buy[item_id] = (buy[item_id] or 0) + qty
            end
        end
    end

    if payload and payload.cart_sell then
        for _, line in ipairs(payload.cart_sell) do
            local item_id = line.item_id or line.id
            local qty = tonumber(line.qty) or 0
            if item_id and qty > 0 then
                sell[item_id] = (sell[item_id] or 0) + qty
            end
        end
    end

    if payload and payload.cart then
        for _, line in ipairs(payload.cart) do
            local side = line.side or line.source
            local item_id = line.item_id or line.id
            local qty = tonumber(line.qty) or 0
            if item_id and qty > 0 then
                if side == "vendor" or side == "buy" then
                    buy[item_id] = (buy[item_id] or 0) + qty
                elseif side == "player" or side == "sell" then
                    sell[item_id] = (sell[item_id] or 0) + qty
                end
            end
        end
    end

    return buy, sell
end

local function ValidateAndApply(player, state, session, cart_buy, cart_sell)
    local shop = SHOPS and SHOPS.Get and SHOPS.Get(session.shop_id)
    if not shop then return false, "unknown_shop" end

    local currency_id = shop.currency or "caps"
    local mods = GetPriceModifiers(shop)

    local total_buy, total_sell, delta = ComputeTotals(cart_buy, cart_sell, shop, mods)

    local vendor_caps = session.vendor_caps or shop.caps or 9999
    local player_caps = WALLET and WALLET.Get and WALLET.Get(state.wallet, currency_id) or 0

    if delta > player_caps then
        return false, "not_enough_player_caps"
    end
    if delta < 0 and math.abs(delta) > vendor_caps then
        return false, "not_enough_vendor_caps"
    end

    for item_id, qty in pairs(cart_sell or {}) do
        if qty > 0 then
            if not shop.sell or not shop.sell[item_id] then
                return false, "not_buying"
            end
            if INV.Count(state.inventory, item_id) < qty then
                return false, "not_owned"
            end
        end
    end

    for item_id, qty in pairs(cart_buy or {}) do
        if qty > 0 then
            if not shop.buy or not shop.buy[item_id] then
                return false, "not_for_sale"
            end
            local stock = GetStockQty(shop, item_id)
            if stock ~= nil and qty > stock then
                return false, "out_of_stock"
            end
            local def = ITEMS and ITEMS.Get and ITEMS.Get(item_id)
            if not def then
                return false, "unknown_item"
            end
            local ok, err = CanAddToInventory(state.inventory, item_id, qty)
            if not ok then
                return false, err
            end
        end
    end

    if delta > 0 then
        WALLET.Spend(state.wallet, currency_id, delta)
        vendor_caps = vendor_caps + delta
    elseif delta < 0 then
        WALLET.Add(state.wallet, currency_id, -delta)
        vendor_caps = vendor_caps + delta
    end

    for item_id, qty in pairs(cart_sell or {}) do
        if qty > 0 then
            INV.Remove(state.inventory, item_id, qty)
            if shop.stock then
                local stock = GetStockQty(shop, item_id)
                SetStockQty(shop, item_id, stock + qty)
            end
        end
    end

    for item_id, qty in pairs(cart_buy or {}) do
        if qty > 0 then
            local ok = INV.Add(state.inventory, item_id, qty)
            if not ok then
                return false, "inventory_add_failed"
            end
            if shop.stock then
                local stock = GetStockQty(shop, item_id)
                SetStockQty(shop, item_id, stock - qty)
            end
        end
    end

    session.vendor_caps = vendor_caps
    return true, nil
end

function SHOP.BeginSession(player, shop_id)
    local shop = SHOPS and SHOPS.Get and SHOPS.Get(shop_id)
    if not shop then
        Warn("BeginSession unknown shop_id=" .. tostring(shop_id))
        return false
    end

    local session = {
        shop_id = shop_id,
        vendor_caps = shop.caps or 9999,
        cart_buy = {},
        cart_sell = {}
    }

    SHOP.SESSIONS[player] = session
    local payload = BuildSnapshot(player, session)
    if not payload then
        Warn("BeginSession build snapshot failed")
        return false
    end

    SendOpen(player, payload)
    FreezePlayerForShop(player, true)
    SetMode(player, "shop")
    return true
end

function SHOP.EndSession(player)
    if not SHOP.SESSIONS[player] then return end
    SHOP.SESSIONS[player] = nil
    SendClose(player)
    FreezePlayerForShop(player, false)
    SetMode(player, "gameplay")
end

function SHOP.Open(player, shop_id)
    return SHOP.BeginSession(player, shop_id)
end

Events.SubscribeRemote("FNV:Shop:Accept", function(player, payload)
    local session = SHOP.SESSIONS[player]
    if not session then return end

    local shop = SHOPS and SHOPS.Get and SHOPS.Get(session.shop_id)
    if not shop then return end
    local mods = GetPriceModifiers(shop)

    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state then
        SHOP.EndSession(player)
        return
    end

    local function CopyCart(src)
        local out = {}
        for item_id, qty in pairs(src or {}) do
            if qty and qty > 0 then out[item_id] = qty end
        end
        return out
    end

    local cart_buy, cart_sell
    if payload and (payload.cart_buy or payload.cart_sell or payload.cart) then
        cart_buy, cart_sell = ParseCartSnapshot(payload)
    else
        -- UI doesn't send cart snapshot yet; use server-side cart.
        cart_buy = CopyCart(session.cart_buy)
        cart_sell = CopyCart(session.cart_sell)
    end

    Log(string.format("Accept shop=%s cart_buy=%s cart_sell=%s",
        tostring(session.shop_id),
        JSON.stringify(cart_buy),
        JSON.stringify(cart_sell)
    ))

    local ok, err = ValidateAndApply(player, state, session, cart_buy, cart_sell)
    if not ok then
        Warn("Transaction failed: " .. tostring(err))
    end
    local tx_buy = BuildCartList(cart_buy, shop, mods, "buy")
    local tx_sell = BuildCartList(cart_sell, shop, mods, "sell")
    session.last_tx = {
        ok = ok,
        err = err,
        cart_buy = tx_buy,
        cart_sell = tx_sell
    }
    if not ok then
        if HUD_NOTIFY and HUD_NOTIFY.Send then
            HUD_NOTIFY.Send(player, "Transaction failed: " .. tostring(err), 2000)
        end
    end

    ResetCart(session)

    if HUD_SYNC and HUD_SYNC.MarkDirty then
        HUD_SYNC.MarkDirty(state)
        if HUD_SYNC.Flush then HUD_SYNC.Flush(player, state) end
    end

    local payload2 = BuildSnapshot(player, session)
    if payload2 then
        SendOpen(player, payload2)
    end

    session.last_tx = nil
end)

Events.SubscribeRemote("FNV:Shop:Select", function(player, payload)
    Log(string.format("Shop:Select player=%s side=%s item_id=%s action=%s amount=%s index=%s",
        tostring(player),
        tostring(payload and payload.side),
        tostring(payload and payload.item_id),
        tostring(payload and payload.action),
        tostring(payload and payload.amount),
        tostring(payload and payload.index)
    ))

    local session = SHOP.SESSIONS[player]
    if not session then return end

    local shop = SHOPS and SHOPS.Get and SHOPS.Get(session.shop_id)
    if not shop then return end

    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state or not state.inventory then return end

    local side = payload and payload.side
    local item_id = payload and (payload.item_id or payload.id)
    if not item_id then return end

    local action = payload and payload.action or "toggle"
    local amount = tonumber(payload and payload.amount) or 1
    if amount < 1 then amount = 1 end

    local cart = nil
    local max_qty = nil
    if side == "vendor" then
        cart = session.cart_buy
        if not shop.buy or not shop.buy[item_id] then return end
        local stock = GetStockQty(shop, item_id)
        if stock ~= nil then max_qty = tonumber(stock) or 0 end
    elseif side == "player" then
        cart = session.cart_sell
        if not shop.sell or not shop.sell[item_id] then return end
        max_qty = INV.Count(state.inventory, item_id)
    else
        return
    end

    if not cart then return end
    local current = tonumber(cart[item_id]) or 0

    if action == "toggle" then
        if current > 0 then
            cart[item_id] = 0
        else
            cart[item_id] = 1
        end
    elseif action == "add" then
        cart[item_id] = current + amount
    elseif action == "remove" then
        cart[item_id] = current - amount
    else
        return
    end

    local next_qty = tonumber(cart[item_id]) or 0
    if max_qty ~= nil then
        if next_qty > max_qty then next_qty = max_qty end
    end
    if next_qty < 0 then next_qty = 0 end

    cart[item_id] = next_qty
    Log(string.format("Shop:Select cart_update side=%s item_id=%s qty=%s",
        tostring(side),
        tostring(item_id),
        tostring(next_qty)
    ))

    local payload2 = BuildSnapshot(player, session)
    if payload2 then
        SendOpen(player, payload2)
    end

    session.last_tx = nil
end)

Events.SubscribeRemote("FNV:Shop:CloseRequest", function(player, payload)
    if not SHOP.SESSIONS[player] then return end
    SHOP.EndSession(player)
end)

Player.Subscribe("Destroy", function(player)
    SHOP.SESSIONS[player] = nil
    FreezePlayerForShop(player, false)
end)
