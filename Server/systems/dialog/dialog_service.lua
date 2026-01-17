DIALOG = DIALOG or {}
DIALOG.SESSIONS = DIALOG.SESSIONS or {}
DIALOG._PARLEY_READY = DIALOG._PARLEY_READY or false

local Parley = require("parley/Shared/parley/core.lua")

local function LogInfo(msg)
    if LOG and LOG.Info then
        LOG.Info(msg)
    else
        Console.Log(msg)
    end
end

local function LogWarn(msg)
    if LOG and LOG.Warn then
        LOG.Warn(msg)
    else
        Console.Log(msg)
    end
end

local function LogError(msg)
    if LOG and LOG.Error then
        LOG.Error(msg)
    else
        Console.Log(msg)
    end
end

local function LookAtRotation(from, to)
    local dx = to.X - from.X
    local dy = to.Y - from.Y
    local dz = to.Z - from.Z

    local yaw = math.deg(math.atan(dy, dx))
    local dist_xy = math.sqrt(dx * dx + dy * dy)
    if dist_xy < 0.001 then dist_xy = 0.001 end
    local pitch = -math.deg(math.atan(dz, dist_xy))
    return Rotator(pitch, yaw, 0)
end

local function FreezePlayerForDialog(player, freeze)
    local char = player:GetControlledCharacter()
    if not char or not char:IsValid() then return end
    char:SetInputEnabled(not freeze)
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

local function CloseInternal(player, mode_override)
    local sess = DIALOG.SESSIONS[player]
    if not sess or sess.closed then return end
    sess.closed = true

    local npc_char = NPC and NPC.List and NPC.List[sess.npc_id] and NPC.List[sess.npc_id].character
    ScheduleNPCReset(npc_char, sess.npc_original_rot, 350)
    RestorePlayerCameraMode(player, sess.camera_mode)

    DIALOG.SESSIONS[player] = nil

    FreezePlayerForDialog(player, false)
    Events.CallRemote("FNV:Dialog:Close", player, { open = false })
    SetMode(player, mode_override or "gameplay")

    if sess.pending_shop_id and SHOP and SHOP.Open then
        local shop_id = sess.pending_shop_id
        local selected = sess.pending_shop_selected
        Timer.SetTimeout(function()
            SHOP.Open(player, shop_id, selected)
        end, 0)
    end
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
    return (dx * dx + dy * dy + dz * dz) <= (range * range)
end

local function ParseAction(action)
    if type(action) ~= "string" then return nil, nil end
    action = action:gsub("^%s+", ""):gsub("%s+$", "")
    action = action:gsub("^set%s+", "")
    local cmd, rest = action:match("^(%S+)%s*(.*)$")
    return cmd, rest
end

function DIALOG.ApplyAction(player, action)
    local sess = DIALOG.SESSIONS[player]
    if not action or not sess then return end

    local cmd, rest = ParseAction(action)
    if not cmd then return end

    if cmd == "open_shop" and rest and rest ~= "" then
        sess.pending_shop_id = rest
        return
    end

    if cmd == "reputation" then
        local op, amount = rest:match("^([%+%-]=)%s*(-?%d+)$")
        if op and amount then
            local current = player:GetValue("rep") or 0
            local delta = tonumber(amount) or 0
            if op == "+=" then
                current = current + delta
            else
                current = current - delta
            end
            player:SetValue("rep", current)
            return
        end
        local value = rest:match("^=%s*(-?%d+)$")
        if value then
            player:SetValue("rep", tonumber(value) or 0)
            return
        end
    end

    if LOG and LOG.Warn then
        LOG.Warn("[DIALOG] Unhandled action: " .. tostring(action))
    else
        LogWarn("[DIALOG] Unhandled action: " .. tostring(action))
    end
end

local function BuildPayloadForSession(sess, line, options)
    if not sess then return nil end
    local npc_name = sess.npc_name
    if line and line.speaker and line.speaker ~= "" then
        npc_name = line.speaker
    end
    local text = line and line.text or nil
    return {
        open = true,
        npc = { id = sess.npc_id, name = npc_name or sess.npc_id },
        node = { id = sess.node_id, text = text },
        options = options or {},
        selected = 0,
        can_close = true
    }
end

local function EnsureParley()
    if DIALOG._PARLEY_READY then return end

    Parley.RegisterStateProvider(function(player)
        return {
            get = function(_, path)
                if path == "player.name" then
                    return player:GetName()
                end
                if path == "player.reputation" then
                    return player:GetValue("rep") or 0
                end
                return nil
            end,
            apply = function(_, action)
                DIALOG.ApplyAction(player, action)
            end
        }
    end)

    Parley.SetUIAdapter({
        show_line = function(player, line, session)
            local sess = DIALOG.SESSIONS[player]
            if not sess then return end
            if sess.session_id == nil then
                sess.session_id = session.id
            elseif sess.session_id ~= session.id then
                return
            end
            sess.node_id = tostring(session.id)
            sess.last_line = line
            sess.last_choices = nil
            LogInfo(string.format("[DIALOG] Parley line npc=%s session=%s", tostring(sess.npc_id), tostring(session.id)))
            local options = {}
            if not sess.last_choices or #sess.last_choices == 0 then
                options[1] = { id = "next", text = "Continuer", used = false, disabled = false, close = false }
            end
            Open(player, BuildPayloadForSession(sess, line, options))
        end,
        show_choices = function(player, choices, session)
            local sess = DIALOG.SESSIONS[player]
            if not sess then return end
            if sess.session_id == nil then
                sess.session_id = session.id
            elseif sess.session_id ~= session.id then
                return
            end
            sess.node_id = tostring(session.id)
            sess.last_choices = choices or {}
            LogInfo(string.format("[DIALOG] Parley choices npc=%s session=%s count=%d", tostring(sess.npc_id), tostring(session.id), #sess.last_choices))
            local options = {}
            for _, choice in ipairs(sess.last_choices) do
                options[#options + 1] = {
                    id = choice.id,
                    text = choice.text,
                    used = false,
                    disabled = false,
                    close = false
                }
            end
            Open(player, BuildPayloadForSession(sess, sess.last_line, options))
        end,
        hide = function(player, session)
            local sess = DIALOG.SESSIONS[player]
            if not sess then return end
            if sess.session_id == nil then
                sess.session_id = session.id
            elseif sess.session_id ~= session.id then
                return
            end
            CloseInternal(player, "gameplay")
        end
    })

    DIALOG._PARLEY_READY = true
end

local function LoadAsset(npc_def, npc_id)
    if not npc_def then return nil end
    if npc_def._asset then return npc_def._asset end
    local ok_file, file_or_err = pcall(File, npc_def.file)
    if not ok_file or not file_or_err then
        LogError("[DIALOG] Parley file open failed: " .. tostring(file_or_err))
        return nil
    end
    local ok_read, text_or_err = pcall(function()
        return file_or_err:Read()
    end)
    if not ok_read or not text_or_err then
        LogError("[DIALOG] Parley file read failed: " .. tostring(text_or_err))
        return nil
    end
    local ok, asset_or_err = pcall(Parley.Load, text_or_err, {
        id = npc_id,
        cache = true,
        is_string = true,
        file = npc_def.file
    })
    if not ok then
        LogError("[DIALOG] Parley load failed: " .. tostring(asset_or_err))
        return nil
    end
    npc_def._asset = asset_or_err
    return npc_def._asset
end

function DIALOG.Start(player, npc_id)
    EnsureParley()
    if DIALOG.SESSIONS[player] or Parley.IsRunning(player) then
        LogWarn("[DIALOG] Start ignored: session already running")
        return
    end
    if not IsNearNPC(player, npc_id, 350) then
        LogWarn("[DIALOG] Start ignored: not near npc_id=" .. tostring(npc_id))
        return
    end

    local npc_def = DIALOG_DB.GetNPC(npc_id)
    if not npc_def then
        LogWarn("[DIALOG] Start ignored: missing npc_def for npc_id=" .. tostring(npc_id))
        return
    end

    local asset = LoadAsset(npc_def, npc_id)
    if not asset then
        LogError("[DIALOG] Start failed: asset not loaded for npc_id=" .. tostring(npc_id))
        return
    end

    local npc_char = NPC and NPC.List and NPC.List[npc_id] and NPC.List[npc_id].character

    local npc_original_rot = nil
    if npc_char and npc_char:IsValid() then
        npc_original_rot = npc_char:GetRotation()
    end

    DIALOG.SESSIONS[player] = {
        npc_id = npc_id,
        npc_name = npc_def.name or npc_id,
        npc_original_rot = npc_original_rot,
        last_face_time = os.clock(),
        camera_mode = ForcePlayerCameraMode(player, CameraMode.FPSOnly),
        node_id = "start",
        session_id = nil,
        last_line = nil,
        last_choices = nil,
        pending_shop_id = nil,
        pending_shop_selected = nil,
        closed = false
    }

    if npc_char then
        FaceNPCToPlayer(npc_char, player)
    end

    FreezePlayerForDialog(player, true)
    SetMode(player, "dialog")

    if npc_char then
        SnapCameraToNPC(player, npc_char)
    end

    local session_id = Parley.Start(player, asset, {
        entry = npc_def.entry or "start",
        context = { npc_id = npc_id },
        on_end = function(_, reason)
            local sess = DIALOG.SESSIONS[player]
            if sess then
                LogInfo("[DIALOG] Parley end reason=" .. tostring(reason))
            end
        end
    })

    local sess = DIALOG.SESSIONS[player]
    if sess then
        sess.session_id = session_id
        sess.node_id = tostring(session_id)
    end
end

Events.SubscribeRemote("FNV:Dialog:Choose", function(player, payload)
    local s = DIALOG.SESSIONS[player]
    if not s then return end

    local npc_id = payload and payload.npc_id
    local node_id = payload and payload.node_id
    local option_id = payload and payload.option_id

    if npc_id ~= s.npc_id or tostring(node_id) ~= tostring(s.node_id) then
        return CloseInternal(player)
    end

    if not IsNearNPC(player, npc_id, 350) then
        return CloseInternal(player)
    end

    if option_id == "next" then
        return Parley.Continue(player, s.session_id)
    end

    local choice_id = tonumber(option_id)
    if choice_id then
        return Parley.SelectChoice(player, s.session_id, choice_id)
    end
end)

Events.SubscribeRemote("FNV:Dialog:CloseRequest", function(player, payload)
    local s = DIALOG.SESSIONS[player]
    if not s then return end
    Parley.Stop(player, s.session_id, "close_request")
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
