ADMIN = {}

ADMIN.WHITELIST = {
    "76561198072645653"
}

function ADMIN.IsAdmin(player)
    if not player.GetSteamID then return false end
    local sid = tostring(player:GetSteamID())
    for _, allowed in ipairs(ADMIN.WHITELIST) do
        if sid == allowed then return true end
    end
    return false
end
