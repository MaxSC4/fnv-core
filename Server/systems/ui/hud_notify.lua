HUD_NOTIFY = {}

function HUD_NOTIFY.Send(player, text, ms)
    Events.CallRemote("FNV:HUD:Notify", player, {
        text = tostring(text),
        ms = ms or 2500
    })
end
