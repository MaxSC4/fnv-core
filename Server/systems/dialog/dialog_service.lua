DIALOG = DIALOG or {}
DIALOG.SESSIONS = DIALOG.SESSIONS or {} -- player -> { npc_id, node_id }

local function LookAtRotation(from, to)
    local dx = to.X - from.X
    local dy = to.Y - from.Y
    local dz = to.Z - from.Z

    local yaw = math.deg(math.atan(dy, dx))
    local dist_xy = math.sqrt(dx*dx + dy*dy)
    if dist_xy < 0.001 then dist_xy = 0.001 end
    local pitch = -math.deg(math.atan(dz, dist_xy))
    return Rotator(pitch, yaw, 0)
end

local function FreezePlayerForDialog(player, freeze)
    local char = player:GetControlledCharacter()
    if not char or not char:IsValid() then return end

    -- bloque le déplacement / actions côté gameplay (server autoritaire)
    char:SetInputEnabled(not freeze)

    -- optionnel (si dispo dans ton autocomplete Nanos)
    -- char:SetCanAim(not freeze)
    -- char:SetCanPunch(not freeze)
    -- char:SetCanSprint(not freeze)
end

local function ForcePlayerCameraMode(player, mode)
    local char = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if not char or not char.IsValid or not char:IsValid() then return nil end
    if char.GetCameraMode and char.SetCameraMode and CameraMode then
        local prev = char:GetCameraMode()
        char:SetCameraMode(mode)
        return prev
    end
    return nil
end

local function RestorePlayerCameraMode(player, prev_mode)
    if prev_mode == nil then return end
    local char = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if not char or not char.IsValid or not char:IsValid() then return end
    if char.SetCameraMode and CameraMode then
        char:SetCameraMode(prev_mode)
    end
end

local function FaceNPCToPlayer(npc_char, player)
    local pchar = player:GetControlledCharacter()
    if not pchar or not pchar:IsValid() then return end
    if not npc_char or not npc_char:IsValid() then return end

    npc_char:LookAt(pchar:GetLocation())
end

local function NormalizeYaw(yaw)
    yaw = yaw % 360
    if yaw < 0 then yaw = yaw + 360 end
    return yaw
end

local function YawDelta(from, to)
    local d = NormalizeYaw(to) - NormalizeYaw(from)
    if d > 180 then d = d - 360 end
    if d < -180 then d = d + 360 end
    return d
end

local function ResetNPCLook(npc_char, original_rot)
    if not npc_char or not npc_char:IsValid() then return end
    if original_rot then
        npc_char:SetRotation(original_rot)
    end

    if npc_char.ClearLookAt then
        npc_char:ClearLookAt()
        return
    end
    if npc_char.StopLookAt then
        npc_char:StopLookAt()
        return
    end

    local fwd = nil
    if original_rot then
        local yaw = math.rad(original_rot.Yaw or 0)
        local pitch = math.rad(original_rot.Pitch or 0)
        fwd = Vector(
            math.cos(pitch) * math.cos(yaw),
            math.cos(pitch) * math.sin(yaw),
            math.sin(pitch)
        )
    elseif npc_char.GetForwardVector then
        fwd = npc_char:GetForwardVector()
    end

    if fwd then
        npc_char:LookAt(npc_char:GetLocation() + (fwd * 100))
    end
end

local function ScheduleNPCReset(npc_char, original_rot, delay_ms)
    delay_ms = delay_ms or 250
    Timer.SetTimeout(function()
        ResetNPCLook(npc_char, original_rot)
    end, delay_ms)

    Timer.SetTimeout(function()
        ResetNPCLook(npc_char, original_rot)
    end, delay_ms + 150)
end

local function FaceNPCBodyToPlayer(npc_char, player, max_head_yaw, yaw_speed, dt)
    local pchar = player:GetControlledCharacter()
    if not pchar or not pchar:IsValid() then return end
    if not npc_char or not npc_char:IsValid() then return end

    local npos = npc_char:GetLocation()
    local ppos = pchar:GetLocation()
    local dx = ppos.X - npos.X
    local dy = ppos.Y - npos.Y
    local target_yaw = math.deg(math.atan(dy, dx))

    local nrot = npc_char:GetRotation()
    local delta = YawDelta(nrot.Yaw, target_yaw)
    if math.abs(delta) > max_head_yaw then
        local step = yaw_speed * dt
        if step < 0 then step = 0 end
        if step > 180 then step = 180 end
        local new_yaw = nrot.Yaw + math.max(-step, math.min(step, delta))
        npc_char:SetRotation(Rotator(0, new_yaw, 0))
    end

    npc_char:LookAt(ppos)
end

local function SnapCameraToNPC(player, npc_char)
    local pchar = player:GetControlledCharacter()
    if not pchar or not pchar:IsValid() then return end
    if not npc_char or not npc_char:IsValid() then return end

    local from = pchar:GetLocation() + Vector(0, 0, 70)
    local to = npc_char:GetLocation() + Vector(0, 0, 70)

    player:SetCameraRotation(LookAtRotation(from, to))
end

local function SetMode(player, mode)
    Events.CallRemote("FNV:UI:SetMode", player, { mode = mode })
end

local function Open(player, payload)
    Events.CallRemote("FNV:Dialog:Open", player, payload)
end

local function Close(player, mode_override)
    local sess = DIALOG.SESSIONS[player]
    if sess then
        local npc_char = NPC and NPC.List and NPC.List[sess.npc_id] and NPC.List[sess.npc_id].character
        ScheduleNPCReset(npc_char, sess.npc_original_rot, 350)
        RestorePlayerCameraMode(player, sess.camera_mode)
    end

    DIALOG.SESSIONS[player] = nil

    FreezePlayerForDialog(player, false)

    Events.CallRemote("FNV:Dialog:Close", player, { open = false })
    SetMode(player, mode_override or "gameplay")
end

local function GetSeen(player)
    local st = PLAYERS.GetState(player)
    if not st then return nil end
    st.dialog_seen = st.dialog_seen or {}
    return st.dialog_seen
end

local function SeenKey(node_id, option_id)
    return tostring(node_id) .. ":" .. tostring(option_id)
end

local function IsSeen(player, npc_id, node_id, option_id)
    local seen = GetSeen(player)
    if not seen or not seen[npc_id] then return false end
    return seen[npc_id][SeenKey(node_id, option_id)] == true
end

local function MarkSeen(player, npc_id, node_id, option_id)
    local seen = GetSeen(player)
    if not seen then return end
    seen[npc_id] = seen[npc_id] or {}
    seen[npc_id][SeenKey(node_id, option_id)] = true
end

local function IsNearNPC(player, npc_id, range)
    range = range or 350
    local data = NPC and NPC.List and NPC.List[npc_id]
    if not data or not data.character or not data.character:IsValid() then return false end

    local pchar = player:GetControlledCharacter()
    if not pchar then return false end

    local ppos = pchar:GetLocation()
    local npos = data.character:GetLocation()
    local dx = ppos.X - npos.X
    local dy = ppos.Y - npos.Y
    local dz = ppos.Z - npos.Z
    return (dx*dx + dy*dy + dz*dz) <= (range*range)
end

local function BuildPayload(player, npc_id, node_id)
    local npc_def = DIALOG_DB.GetNPC(npc_id)
    if not npc_def then return nil end

    local node = npc_def.nodes[node_id]
    if not node then return nil end

    local opts = {}
    for _, opt in ipairs(node.options or {}) do
        opts[#opts+1] = {
            id = opt.id,
            text = opt.text,
            used = IsSeen(player, npc_id, node_id, opt.id),
            disabled = opt.disabled or false,
            close = opt.close or false,
            action = opt.action,
        }
    end

    return {
        open = true,
        npc = { id = npc_id, name = npc_def.name or npc_id },
        node = { id = node_id, text = node.text },
        options = opts,
        selected = 0, -- 0-based
        can_close = true
    }
end

function DIALOG.Start(player, npc_id)
    if DIALOG.SESSIONS[player] then return end -- déjà en dialogue
    if not IsNearNPC(player, npc_id, 350) then return end

    local npc_def = DIALOG_DB.GetNPC(npc_id)
    if not npc_def then return end

    local node_id = npc_def.start or "root"

    local npc_char = NPC and NPC.List and NPC.List[npc_id] and NPC.List[npc_id].character

    local npc_original_rot = nil
    if npc_char and npc_char:IsValid() then
        npc_original_rot = npc_char:GetRotation()
    end

    DIALOG.SESSIONS[player] = { 
        npc_id = npc_id, 
        node_id = node_id,
        npc_original_rot = npc_original_rot,
        last_face_time = os.clock(),
        camera_mode = ForcePlayerCameraMode(player, CameraMode.FPSOnly)
    }

    -- 1) le PNJ se tourne vers le joueur
    if npc_char then
        FaceNPCToPlayer(npc_char, player)
    end

    -- 2) on bloque les inputs gameplay (déplacement etc)
    FreezePlayerForDialog(player, true)

    -- 3) on passe en mode dialog (ça va aussi activer souris côté client)
    SetMode(player, "dialog")

    -- 4) on “snap” la caméra vers le PNJ
    if npc_char then
        SnapCameraToNPC(player, npc_char)
    end

    -- 5) ouvre le dialogue
    local payload = BuildPayload(player, npc_id, node_id)
    Open(player, payload)
end


Events.SubscribeRemote("FNV:Dialog:Choose", function(player, payload)
    local s = DIALOG.SESSIONS[player]
    if not s then return end

    local npc_id = payload and payload.npc_id
    local node_id = payload and payload.node_id
    local option_id = payload and payload.option_id

    if npc_id ~= s.npc_id or node_id ~= s.node_id then
        return Close(player)
    end

    if not IsNearNPC(player, npc_id, 350) then
        return Close(player)
    end

    local npc_def = DIALOG_DB.GetNPC(npc_id)
    local node = npc_def and npc_def.nodes and npc_def.nodes[node_id]
    if not node then
        return Close(player)
    end

    local chosen = nil
    for _, opt in ipairs(node.options or {}) do
        if opt.id == option_id then chosen = opt break end
    end
    if not chosen or chosen.disabled then return end

    MarkSeen(player, npc_id, node_id, option_id)

    if chosen.close then
        return Close(player)
    end

    if chosen.next then
        s.node_id = chosen.next
        return Open(player, BuildPayload(player, npc_id, s.node_id))
    end

    if chosen.action then
        if DIALOG_ACTIONS and DIALOG_ACTIONS.Run then
            local result = DIALOG_ACTIONS.Run(player, chosen) or {}
            if result.close then
                Close(player, result.mode)
                if result.shop_id and SHOP and SHOP.Open then
                    local ok = SHOP.Open(player, result.shop_id, result.selected)
                    if not ok and result.mode == "shop" then
                        Events.CallRemote("FNV:UI:SetMode", player, { mode = "gameplay" })
                    end
                end
                return
            end
            if result.shop_id and SHOP and SHOP.Open then
                SHOP.Open(player, result.shop_id, result.selected)
            end
            if result.next then
                s.node_id = result.next
                return Open(player, BuildPayload(player, npc_id, s.node_id))
            end
            if result.refresh ~= false then
                return Open(player, BuildPayload(player, npc_id, s.node_id))
            end
            return
        else
            if LOG and LOG.Warn then
                LOG.Warn("[DIALOG] Missing DIALOG_ACTIONS for action=" .. tostring(chosen.action))
            end
        end
    end

    -- fallback
    Close(player)
end)

Events.SubscribeRemote("FNV:Dialog:CloseRequest", function(player, payload)
    local s = DIALOG.SESSIONS[player]
    if not s then return end
    Close(player)
end)

Player.Subscribe("Destroy", function(player)
    local sess = DIALOG.SESSIONS[player]
    if sess then
        local npc_char = NPC and NPC.List and NPC.List[sess.npc_id] and NPC.List[sess.npc_id].character
        ResetNPCLook(npc_char, sess.npc_original_rot)
    end
    DIALOG.SESSIONS[player] = nil
end)

Timer.SetInterval(function()
    local max_head_yaw = 60
    local yaw_speed = 20
    local now = os.clock()
    for player, sess in pairs(DIALOG.SESSIONS) do
        if player and (not player.IsValid or player:IsValid()) then
            local npc_char = NPC and NPC.List and NPC.List[sess.npc_id] and NPC.List[sess.npc_id].character
            if npc_char and npc_char:IsValid() then
                local last = sess.last_face_time or now
                local dt = now - last
                if dt < 0 then dt = 0 end
                if dt > 0.5 then dt = 0.5 end
                sess.last_face_time = now
                FaceNPCBodyToPlayer(npc_char, player, max_head_yaw, yaw_speed, dt)
            end
        end
    end
end, 250)





