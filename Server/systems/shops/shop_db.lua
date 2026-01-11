SHOPS = {}

SHOPS.general = {
    name = "Marchand GAcnAcraliste",
    currency = "caps",
    buy = {
        water = 5,
        stimpack = 30
    },
    stock = {
        water = 10,
        stimpack = 5
    },
    sell = {
        water = 2,
        stimpack = 15
    }
}

SHOPS.ultraluxe = {
    name = "Ultra-Luxe Casino",
    currency = "casino_ultraluxe",
    buy = {
        chips = 1
    },
    stock = {
        chips = 1000
    }
}

SHOPS.veronica_shop = {
    name = "Veronica",
    currency = "caps",
    buy = {
        water = 6,
        stimpack = 28
    },
    stock = {
        water = { qty = 6, cnd = 80 },
        stimpack = { qty = 3, cnd = 100 }
    },
    sell = {
        water = 3,
        stimpack = 14
    }
}


function SHOPS.Get(shop_id)
    return SHOPS[shop_id]
end
