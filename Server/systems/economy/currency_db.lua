CURRENCIES = {

    caps = {
        name = "Capsules",
        type = "global",
        tradable = true
    },

    ncr = {
        name = "Dollar NCR",
        type = "faction",
        faction = "NCR",
        tradable = true
    },

    legion = {
        name = "Denarius de la Légion",
        type = "faction",
        faction = "LEGION",
        tradable = true
    },

    casino_ultraluxe = {
        name = "Jetons Ultra-Luxe",
        type = "casino",
        casino_id = "ultraluxe",
        tradable = false
    },

    casino_gomorrah = {
        name = "Jetons Gomorrah",
        type = "casino",
        casino_id = "gomorrah",
        tradable = false
    }
}

function CURRENCIES.Get(id)
    return CURRENCIES[id]
end
