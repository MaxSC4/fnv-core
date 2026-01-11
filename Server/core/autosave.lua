AUTOSAVE = AUTOSAVE or {}

local INTERVAL_MS = 30000 -- 30s

function AUTOSAVE.Start()
    if AUTOSAVE._timer then return end

    AUTOSAVE._timer = Timer.SetInterval(function()
        for _, player in pairs(Player.GetAll()) do
            local state = PLAYERS.GetState(player)
            local player_id = PLAYERS.GetID(player)

            if state and player_id then
                local char = player:GetControlledCharacter()
                if char then
                    state.pos = char:GetLocation()
                end
                state.last_seen = os.time()

                PLAYER_STATE.Save(player_id, state)
                HUD_SYNC.Flush(player, state)
            end
        end

        LOG.Info("[AUTOSAVE] tick")
    end, INTERVAL_MS)
end
