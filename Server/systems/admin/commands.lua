ADM_CMD = {}
ADM_CMD.TEST_COMBAT = ADM_CMD.TEST_COMBAT or {}

local function Reply(player, text, ms)
    Events.CallRemote("FNV:HUD:Notify", player, {
        text = tostring(text),
        ms = ms or 10000
    })
end

local function Split(str)
    local t = {}
    for w in string.gmatch(str, "%S+") do t[#t + 1] = w end
    return t
end

local function GetPlayerKey(player)
    if PLAYERS and PLAYERS.GetID then
        local pid = PLAYERS.GetID(player)
        if pid then return tostring(pid) end
    end
    return tostring(player and player.GetName and player:GetName() or player)
end

local function StopTestCombat(player)
    local key = GetPlayerKey(player)
    local entry = ADM_CMD.TEST_COMBAT[key]
    if not entry then return false end
    if entry.timer then
        Timer.ClearInterval(entry.timer)
    end
    if entry.npc_id and NPC and NPC.List and NPC.List[entry.npc_id] then
        local data = NPC.List[entry.npc_id]
        if data and data.character and data.character.IsValid and data.character:IsValid() then
            data.character:Destroy()
        end
        NPC.List[entry.npc_id] = nil
    end
    ADM_CMD.TEST_COMBAT[key] = nil
    return true
end

local function StartTestCombat(player, state)
    local char = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if not char or not char.IsValid or not char:IsValid() then
        Reply(player, "No character for test combat.")
        return
    end

    local key = GetPlayerKey(player)
    local npc_id = "test_combat_" .. key
    local pos = char:GetLocation() + Vector(500, 0, 0)
    NPC.Spawn(npc_id, pos, Rotator(0, 180, 0), "Test Raider")
    if NPC.SetHostile then
        NPC.SetHostile(npc_id, true)
    end
    local npc = NPC.List[npc_id] and NPC.List[npc_id].character
    if npc and npc.IsValid and npc:IsValid() and npc.LookAt then
        npc:LookAt(char:GetLocation())
    end

    local timer_id = Timer.SetInterval(function()
        local ply = player
        if not ply or (ply.IsValid and not ply:IsValid()) then
            StopTestCombat(player)
            return
        end
        local st = PLAYERS.GetState(ply)
        if not st then return end
        if HP and HP.ApplyIncomingDamage then
            HP.ApplyIncomingDamage(ply, st, 12)
        elseif HUD_SYNC and HUD_SYNC.Damage then
            HUD_SYNC.Damage(ply, st, 12)
        end
    end, 1000)

    ADM_CMD.TEST_COMBAT[key] = { timer = timer_id, npc_id = npc_id }
    Reply(player, "Test combat started (NPC + periodic damage).")
end

local function MarkAndFlush(player, state)
    if HUD_SYNC.MarkDirty then HUD_SYNC.MarkDirty(state) end
    if HUD_SYNC.Flush then HUD_SYNC.Flush(player, state) else HUD_SYNC.Send(player, state) end
end

local function ApplySpecial(state, key, value)
    state.special = state.special or {}
    state.special[key] = value
    if SPECIAL and SPECIAL.Init then
        SPECIAL.Init(state)
    end
    if AP and AP.Init then
        AP.Init(state)
    end
    if HP and HP.Init then
        HP.Init(state)
    end
end

function ADM_CMD.Handle(player, message)
    if not ADMIN.IsAdmin(player) then
        return Reply(player, "Accès refusé.")
    end

    local state = PLAYERS.GetState(player)
    local pid = PLAYERS.GetID(player)
    if not state or not pid then
        return Reply(player, "State non chargé.")
    end

    local args = Split(message)
    local cmd = (args[1] or ""):lower()

    if cmd == "/help" then
        return Reply(player, "Cmds: /money <currency> <amt> | /take <currency> <amt> | /giveitem <id> [amt] | /heal <amt> | /dmg <amt> | /save | /test_combat | /respawn | /strength /perception /endurance /charisma /intelligence /agility /luck <value>")
    end

    if cmd == "/money" then
        local currency = tostring(args[2] or "")
        local amt = tonumber(args[3] or "")
        if currency == "" or not amt then return Reply(player, "Usage: /money <currency> <amount>") end

        local ok, err = WALLET.Add(state.wallet, currency, amt)
        if not ok then return Reply(player, "Erreur: " .. tostring(err)) end

        Reply(player, "+" .. amt .. " " .. currency)
        MarkAndFlush(player, state)
        return
    end

    if cmd == "/take" then
        local currency = tostring(args[2] or "")
        local amt = tonumber(args[3] or "")
        if currency == "" or not amt then return Reply(player, "Usage: /take <currency> <amount>") end

        local ok, err = WALLET.Spend(state.wallet, currency, amt)
        if not ok then return Reply(player, "Erreur: " .. tostring(err)) end

        Reply(player, "-" .. amt .. " " .. currency)
        MarkAndFlush(player, state)
        return
    end

    if cmd == "/giveitem" then
        local item_id = tostring(args[2] or "")
        local amt = tonumber(args[3] or "1") or 1
        if item_id == "" then return Reply(player, "Usage: /giveitem <item_id> [amount]") end

        local ok, err = INV.Add(state.inventory, item_id, amt)
        if not ok then return Reply(player, "Erreur: " .. tostring(err)) end

        Reply(player, "Item +" .. amt .. " " .. item_id)
        -- (HUD ne montre pas inventaire pour l’instant, mais on flush quand même)
        MarkAndFlush(player, state)
        return
    end

    if cmd == "/heal" then
        local amt = tonumber(args[2] or "")
        if not amt then
            return Reply(player, "Usage: /heal <amount>", 3000)
        end

        HUD_SYNC.Heal(player, state, amt)

        return Reply(player, "Heal +" .. amt .. " (HP=" .. tostring(state.hp) .. ")", 2500)
    end

    if cmd == "/dmg" then
        local amt = tonumber(args[2] or "")
        if not amt then
            return Reply(player, "Usage: /dmg <amount>", 3000)
        end

        HUD_SYNC.Damage(player, state, amt) -- clamp + HUD_SYNC.Send()

        return Reply(player, "Dmg -" .. amt .. " (HP=" .. tostring(state.hp) .. ")", 2500)
    end

    if cmd == "/save" then
        state.last_seen = os.time()
        local char = player:GetControlledCharacter()
        if char then state.pos = char:GetLocation() end
        PLAYER_STATE.Save(pid, state)
        return Reply(player, "Sauvegardé.")
    end

    if cmd == "/test_combat" then
        if StopTestCombat(player) then
            return Reply(player, "Test combat stopped.")
        end
        StartTestCombat(player, state)
        return
    end


        if cmd == "/strength" or cmd == "/perception" or cmd == "/endurance" or cmd == "/charisma" or cmd == "/intelligence" or cmd == "/agility" or cmd == "/luck" then
        local val = tonumber(args[2] or "")
        if not val then
            return Reply(player, "Usage: /strength|/perception|/endurance|/charisma|/intelligence|/agility|/luck <value>")
        end
        local map = {
            ["/strength"] = "str",
            ["/perception"] = "per",
            ["/endurance"] = "endu",
            ["/charisma"] = "cha",
            ["/intelligence"] = "intel",
            ["/agility"] = "agi",
            ["/luck"] = "lck"
        }
        local key = map[cmd]
        ApplySpecial(state, key, val)
        MarkAndFlush(player, state)
        return Reply(player, "Special updated: " .. tostring(cmd) .. "=" .. tostring(val))
    end

    if cmd == "/respawn" then
        local char = player:GetControlledCharacter()
        if char and char.IsValid and char:IsValid() then
            char:SetLocation(Vector(1400, 800, 300))
        end
        state.hp_max = state.hp_max or 200
        state.hp = state.hp_max
        if HP and HP.SyncCharacterHealth then
            HP.SyncCharacterHealth(player, state)
        elseif HUD_SYNC and HUD_SYNC.SetHP then
            HUD_SYNC.SetHP(player, state, state.hp)
        end
        if char and char.IsValid and char:IsValid() then
            if char.SetCanDie then
                char:SetCanDie(false)
            end
            if char.Respawn then
                char:Respawn()
            end
        end
        return Reply(player, "Respawned.")
    end

Reply(player, "Commande inconnue. /help")
end

-- Client(UI) -> Server
Events.SubscribeRemote("FNV:Admin:Command", function(player, message)
    if type(message) ~= "string" then return end
    message = message:gsub("^%s+", ""):gsub("%s+$", "")
    if message == "" then return end
    if message:sub(1, 1) ~= "/" then message = "/" .. message end

    ADM_CMD.Handle(player, message)
end)
