HUD_NOTIFY = {}

function HUD_NOTIFY.Send(player, text_or_payload, ms, icon)
    if LOG and LOG.Info then
        local name = player and player.GetName and player:GetName() or "unknown"
        if type(text_or_payload) == "table" then
            LOG.Info("[HUD:Notify] to=" .. name .. " payload=table")
        else
            LOG.Info("[HUD:Notify] to=" .. name .. " text=" .. tostring(text_or_payload))
        end
    end
    if type(text_or_payload) == "table" then
        text_or_payload.icon = "popup/glow_content"
        Events.CallRemote("FNV:HUD:Notify", player, text_or_payload)
        return
    end

    local payload = {
        text = tostring(text_or_payload),
        ms = ms or 2500
    }
    payload.icon = "popup/glow_content"
    Events.CallRemote("FNV:HUD:Notify", player, payload)
end
