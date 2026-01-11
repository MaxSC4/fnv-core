HUD_NOTIFY = {}

function HUD_NOTIFY.Send(player, text_or_payload, ms, icon)
    if type(text_or_payload) == "table" then
        Events.CallRemote("FNV:HUD:Notify", player, text_or_payload)
        return
    end

    local payload = {
        text = tostring(text_or_payload),
        ms = ms or 2500
    }
    if icon then
        payload.icon = icon
    end
    Events.CallRemote("FNV:HUD:Notify", player, payload)
end
