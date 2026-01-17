DIALOG_DB = DIALOG_DB or {}

DIALOG_DB.NPCS = {
    veronica = {
        name = "Veronica",
        file = "Packages/fallout-core/Server/dialogues/veronica.txt",
        entry = "start"
    }
}

function DIALOG_DB.GetNPC(npc_id)
    return DIALOG_DB.NPCS[npc_id]
end
