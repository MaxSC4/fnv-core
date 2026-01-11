PLAYERS = {
    by_id = {},         -- [player_id] = state
    id_by_player = {}   -- [Player] = player_id
}

function PLAYERS.GetID(player)
    return PLAYERS.id_by_player[player]
end

function PLAYERS.GetState(player)
    local id = PLAYERS.GetID(player)
    if not id then return nil end
    return PLAYERS.by_id[id]
end

function PLAYERS.Set(player, player_id, state)
    PLAYERS.id_by_player[player] = player_id
    PLAYERS.by_id[player_id] = state
end

function PLAYERS.Remove(player)
    local id = PLAYERS.id_by_player[player]
    PLAYERS.id_by_player[player] = nil
    if id then
        PLAYERS.by_id[id] = nil
    end
end
