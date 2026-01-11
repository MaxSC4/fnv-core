DIALOG_DB = DIALOG_DB or {}

DIALOG_DB.NPCS = {
    veronica = {
        name = "Veronica",
        start = "root",
        nodes = {
            root = {
                text = nil,
                options = {
                    { id = "who", text = "Qui es-tu ?", next = "who" },
                    { id = "trade", text = "Voyons tes marchandises.", action = "open_shop", shop_id = "veronica_shop" },
                    { id = "goodbye", text = "Au revoir.", close = true },
                }
            },
            who = {
                text = "Je m'appelle Veronica.",
                options = {
                    { id = "back", text = "Retour.", next = "root" },
                    { id = "goodbye", text = "Au revoir.", close = true },
                }
            }
        }
    }
}

function DIALOG_DB.GetNPC(npc_id)
    return DIALOG_DB.NPCS[npc_id]
end
