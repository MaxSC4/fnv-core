local UI = nil
local ui_ready = false

local pending_mode = nil
local current_mode = "gameplay"
local pending_dialog_open = nil
local pending_dialog_close = nil
local pending_shop_open = nil
local pending_shop_close = nil
local pending_inv_open = nil
local pending_inv_close = nil
local pending_hud_state = nil
local pending_hud_visible = nil
local pending_interact_prompt = nil
local pending_admin_open = nil
local pending_enemy_target = nil
local pending_container_open = nil
local pending_container_close = nil
local pending_container_transfer_open = nil
local pending_container_transfer_close = nil
local admin_open = false
local saved_camera_mode = nil
local last_enemy_target = { visible = false, id = nil, hp_pct = nil, name = nil }
local SendEnemyTarget
local drop_block = { char = nil }
local current_container_open_id = nil
local current_container_transfer_open_id = nil
local inv_open = false
local inv_modal_open = false

local function ForceFirstPerson()
    local player = Client.GetLocalPlayer()
    if not player or not player.IsValid or not player:IsValid() then return false end

    local char = player.GetControlledCharacter and player:GetControlledCharacter()
    local ok = false
    if char and char.IsValid and char:IsValid() and char.SetCameraMode and CameraMode then
        if saved_camera_mode == nil and char.GetCameraMode then
            saved_camera_mode = char:GetCameraMode()
        end
        char:SetCameraMode(CameraMode.FPSOnly)
        ok = true
    end

    if player.SetCameraMode and CameraMode then
        if saved_camera_mode == nil and player.GetCameraMode then
            saved_camera_mode = player:GetCameraMode()
        end
        player:SetCameraMode(CameraMode.FPSOnly)
        ok = true
    end

    return ok
end

local function RestoreCameraMode()
    if saved_camera_mode == nil then return end

    local player = Client.GetLocalPlayer()
    local char = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if char and char.IsValid and char:IsValid() and char.SetCameraMode and CameraMode then
        char:SetCameraMode(saved_camera_mode)
    end
    if player and player.SetCameraMode and CameraMode then
        player:SetCameraMode(saved_camera_mode)
    end
    saved_camera_mode = nil
end

local function ResetGameplayInput()
    current_mode = "gameplay"
    Input.SetMouseEnabled(false)
    Input.SetInputEnabled(true)
    if UI and UI.IsValid and UI:IsValid() then
        UI:RemoveFocus()
    end
end

local function FlushPending()
    if not UI or not (UI.IsValid and UI:IsValid()) then return end
    if not ui_ready then return end

    if pending_mode then
        UI:CallEvent("UI:SetMode", pending_mode)
        pending_mode = nil
    end

    if pending_dialog_open then
        UI:CallEvent("Dialog:Open", pending_dialog_open)
        pending_dialog_open = nil
    end

    if pending_dialog_close then
        UI:CallEvent("Dialog:Close", pending_dialog_close)
        pending_dialog_close = nil
    end

    if pending_shop_open then
        UI:CallEvent("Shop:Open", pending_shop_open)
        pending_shop_open = nil
    end

    if pending_shop_close then
        UI:CallEvent("Shop:Close", pending_shop_close)
        pending_shop_close = nil
    end

    if pending_inv_open then
        UI:CallEvent("Inv:Open", pending_inv_open)
        pending_inv_open = nil
    end

    if pending_inv_close then
        UI:CallEvent("Inv:Close", pending_inv_close)
        pending_inv_close = nil
    end

    if pending_container_open then
        UI:CallEvent("Container:Open", pending_container_open)
        pending_container_open = nil
    end

    if pending_container_close then
        UI:CallEvent("Container:Close", pending_container_close)
        pending_container_close = nil
    end

    if pending_container_transfer_open then
        UI:CallEvent("Container:TransferOpen", pending_container_transfer_open)
        pending_container_transfer_open = nil
    end

    if pending_container_transfer_close then
        UI:CallEvent("Container:TransferClose", pending_container_transfer_close)
        pending_container_transfer_close = nil
    end

    if pending_hud_state then
        UI:CallEvent("HUD:SetState", pending_hud_state)
        pending_hud_state = nil
    end

    if pending_hud_visible ~= nil then
        UI:CallEvent("HUD:SetVisible", { visible = pending_hud_visible == true })
        pending_hud_visible = nil
    end

    if pending_enemy_target then
        UI:CallEvent("HUD:EnemyTarget", pending_enemy_target)
        pending_enemy_target = nil
    end

    if pending_interact_prompt then
        UI:CallEvent("HUD:InteractPrompt", pending_interact_prompt)
        pending_interact_prompt = nil
    end

    if pending_admin_open ~= nil then
        admin_open = pending_admin_open
        pending_admin_open = nil
        UI:CallEvent("HUD:Admin:SetOpen", admin_open)
    end
end

local function DestroyUI()
    if UI and UI.IsValid and UI:IsValid() then
        UI:RemoveFocus()
        UI:Destroy()
    end
    UI = nil
    ui_ready = false
    pending_mode = nil
    pending_dialog_open = nil
    pending_dialog_close = nil
    pending_shop_open = nil
    pending_shop_close = nil
    pending_inv_open = nil
    pending_inv_close = nil
    pending_hud_state = nil
    pending_hud_visible = nil
    pending_enemy_target = nil
    pending_interact_prompt = nil
    pending_admin_open = nil
    pending_container_open = nil
    pending_container_close = nil
    pending_container_transfer_open = nil
    pending_container_transfer_close = nil
end

local function ToggleAdminConsole()
    pending_admin_open = not admin_open
    FlushPending()
end

Input.Register("FNV_AdminConsole", "F2", "Toggle Admin Console")
Input.Bind("FNV_AdminConsole", InputEvent.Pressed, function()
    ToggleAdminConsole()
end)

Input.Register("FNV_Inventory", "Tab", "Open Inventory")
Input.Bind("FNV_Inventory", InputEvent.Pressed, function()
    if current_mode == "inventory" then
        Events.CallRemote("FNV:Inv:CloseRequest", {})
        return
    end
    if current_mode ~= "gameplay" then return end
    Events.CallRemote("FNV:Inv:OpenRequest", {})
end)

local function SendInvKey(key)
    if not inv_open and current_mode ~= "inventory" then return end
    if inv_modal_open then return end
    if UI and (UI.IsValid and UI:IsValid()) and ui_ready then
        UI:CallEvent("Inv:Key", { key = key })
    end
end

Input.Register("FNV_InvUp", "Up", "Inventory Up")
Input.Register("FNV_InvDown", "Down", "Inventory Down")
Input.Register("FNV_InvLeft", "Left", "Inventory Left")
Input.Register("FNV_InvRight", "Right", "Inventory Right")
Input.Register("FNV_InvAction", "E", "Inventory Action")
Input.Register("FNV_InvActionEnter", "Enter", "Inventory Action")
Input.Register("FNV_InvDrop", "R", "Inventory Drop")
Input.Register("FNV_InvInspect", "I", "Inventory Inspect")
Input.Register("FNV_InvSort", "S", "Inventory Sort")
Input.Register("FNV_InvClose", "Backspace", "Inventory Close")
Input.Register("FNV_BlockDropWeapon", "G", "Block Weapon Drop")
Input.Register("FNV_ContainerUp", "Up", "Container Up")
Input.Register("FNV_ContainerDown", "Down", "Container Down")
Input.Register("FNV_ContainerAction", "E", "Container Take")

Input.Bind("FNV_InvUp", InputEvent.Pressed, function() SendInvKey("up") end)
Input.Bind("FNV_InvDown", InputEvent.Pressed, function() SendInvKey("down") end)
Input.Bind("FNV_InvLeft", InputEvent.Pressed, function() SendInvKey("left") end)
Input.Bind("FNV_InvRight", InputEvent.Pressed, function() SendInvKey("right") end)
Input.Bind("FNV_InvAction", InputEvent.Pressed, function() SendInvKey("action") end)
Input.Bind("FNV_InvActionEnter", InputEvent.Pressed, function() SendInvKey("action") end)
Input.Bind("FNV_InvDrop", InputEvent.Pressed, function() SendInvKey("drop") end)
Input.Bind("FNV_InvInspect", InputEvent.Pressed, function() SendInvKey("inspect") end)
Input.Bind("FNV_InvSort", InputEvent.Pressed, function() SendInvKey("sort") end)
Input.Bind("FNV_InvClose", InputEvent.Pressed, function() SendInvKey("close") end)
Input.Bind("FNV_BlockDropWeapon", InputEvent.Pressed, function()
    -- Block default nanos weapon drop (G)
end)
-- Native bindings: keep empty to swallow engine drop behavior
Input.Bind("DropWeapon", InputEvent.Pressed, function() end)
Input.Bind("DropWeapon", InputEvent.Released, function() end)
Input.Bind("Drop", InputEvent.Pressed, function() end)
Input.Bind("Drop", InputEvent.Released, function() end)

local function SendContainerKey(key)
    if not current_container_open_id then return end
    if current_container_transfer_open_id then return end
    if UI and (UI.IsValid and UI:IsValid()) and ui_ready then
        UI:CallEvent("Container:Key", { key = key })
    end
end

Input.Bind("FNV_ContainerUp", InputEvent.Pressed, function()
    if current_mode ~= "gameplay" and current_mode ~= "container" then return end
    SendContainerKey("up")
end)
Input.Bind("FNV_ContainerDown", InputEvent.Pressed, function()
    if current_mode ~= "gameplay" and current_mode ~= "container" then return end
    SendContainerKey("down")
end)
Input.Bind("FNV_ContainerAction", InputEvent.Pressed, function()
    if current_mode ~= "gameplay" and current_mode ~= "container" then return end
    SendContainerKey("action")
end)

Package.Subscribe("Load", function()
    ResetGameplayInput()
    if WebUI and WebUI.GetByName then
        local existing = WebUI.GetByName("FNV_UI")
        if existing and existing.IsValid and existing:IsValid() then
            existing:Destroy()
        end
    elseif WebUI and WebUI.GetAll then
        for _, w in pairs(WebUI.GetAll()) do
            if w and w.IsValid and w:IsValid() and w.GetName and w:GetName() == "FNV_UI" then
                w:Destroy()
            end
        end
    end

    if UI and UI.IsValid and UI:IsValid() then
        return
    end
    DestroyUI()

    UI = WebUI("FNV_UI", "file://fallout-ui/Client/UI/index.html", WidgetVisibility.Visible)
    UI:RemoveFocus()

    UI:Subscribe("Ready", function()
        if ui_ready then
            return
        end
        ui_ready = true
        print("[FNV] WebUI Ready ✅")

        -- WebUI -> Server
        UI:Subscribe("Dialog:Choose", function(data)
            Events.CallRemote("FNV:Dialog:Choose", data)
        end)

        UI:Subscribe("Dialog:CloseRequest", function(data)
            Events.CallRemote("FNV:Dialog:CloseRequest", data)
        end)

        UI:Subscribe("Shop:Accept", function(data)
            Events.CallRemote("FNV:Shop:Accept", data)
        end)

        UI:Subscribe("Shop:Select", function(data)
            print(string.format("[FNV] Shop:Select side=%s item_id=%s action=%s amount=%s index=%s", tostring(data and data.side), tostring(data and data.item_id), tostring(data and data.action), tostring(data and data.amount), tostring(data and data.index)))
            Events.CallRemote("FNV:Shop:Select", data)
        end)

        UI:Subscribe("Shop:CloseRequest", function(data)
            Events.CallRemote("FNV:Shop:CloseRequest", data)
        end)

        UI:Subscribe("Inv:Action", function(data)
            Events.CallRemote("FNV:Inv:Action", data)
        end)

        UI:Subscribe("Inv:CloseRequest", function(data)
            Events.CallRemote("FNV:Inv:CloseRequest", data)
        end)

        UI:Subscribe("Inv:ModalOpen", function(data)
            inv_modal_open = true
            if UI and (UI.IsValid and UI:IsValid()) then
                Input.SetInputEnabled(false)
                Input.SetMouseEnabled(true)
                UI:SetFocus()
            end
        end)

        UI:Subscribe("Inv:ModalClose", function(data)
            inv_modal_open = false
            if UI and (UI.IsValid and UI:IsValid()) then
                Input.SetInputEnabled(true)
                Input.SetMouseEnabled(true)
                UI:SetFocus()
            end
        end)

        UI:Subscribe("Container:Take", function(data)
            Events.CallRemote("FNV:Container:Take", data)
        end)

        UI:Subscribe("Container:CloseRequest", function(data)
            Events.CallRemote("FNV:Container:CloseRequest", data)
        end)

        UI:Subscribe("Container:TransferMove", function(data)
            Events.CallRemote("FNV:Container:TransferMove", data)
        end)

        UI:Subscribe("Container:TransferTakeAll", function(data)
            Events.CallRemote("FNV:Container:TransferTakeAll", data)
        end)

        UI:Subscribe("Container:TransferCloseRequest", function(data)
            Events.CallRemote("FNV:Container:TransferCloseRequest", data)
        end)

        UI:Subscribe("HUD:AdminCommand", function(text)
            if type(text) ~= "string" then return end
            text = text:gsub("^%s+", ""):gsub("%s+$", "")
            if text == "" then return end
            if text:sub(1, 1) ~= "/" then
                text = "/" .. text
            end
            Events.CallRemote("FNV:Admin:Command", text)
        end)

        FlushPending()
    end)

    UI:Subscribe("Fail", function(code, msg)
        print(string.format("[FNV] WebUI FAIL ❌ code=%s msg=%s", tostring(code), tostring(msg)))
    end)

    -- demande la liste une fois le client charge
    Timer.SetTimeout(function()
        Events.CallRemote("FNV:NPC:RequestList")
        Events.CallRemote("FNV:Loot:RequestList")
        Events.CallRemote("FNV:Container:RequestList")
    end, 500)
end)

Package.Subscribe("Unload", function()
    DestroyUI()
    ResetGameplayInput()
end)

local function BindDropBlocker(character)
    if not character or not character.IsValid or not character:IsValid() then return end
    if drop_block.char == character then return end
    drop_block.char = character
    if character.Subscribe then
        character:Subscribe("Drop", function(_, object)
            if not object or not object.IsA then return end
            if object:IsA(Weapon) then
                Events.CallRemote("FNV:Weapon:ForcePickup", object)
            end
        end)
    end
end

Client.Subscribe("SpawnLocalPlayer", function(local_player)
    if not local_player or not local_player.Subscribe then return end
    local_player:Subscribe("Possess", function(_, character)
        BindDropBlocker(character)
    end)
end)

Package.Subscribe("Load", function()
    local local_player = Client.GetLocalPlayer()
    if local_player and local_player.GetControlledCharacter then
        BindDropBlocker(local_player:GetControlledCharacter())
    end
end)

-- Remote -> WebUI (bufferisé jusqu'à Ready)
local function SendEnemyTarget(visible, name, hp_pct, id)
    if visible then
        local next = {
            visible = true,
            name = name or "Enemy",
            hp_pct = hp_pct or 0
        }
        if last_enemy_target.visible == true
            and last_enemy_target.id == id
            and last_enemy_target.hp_pct == next.hp_pct
            and last_enemy_target.name == next.name then
            return
        end
        last_enemy_target = { visible = true, id = id, hp_pct = next.hp_pct, name = next.name }
        pending_enemy_target = next
        FlushPending()
        return
    end

    if last_enemy_target.visible == false then
        return
    end
    last_enemy_target = { visible = false, id = nil, hp_pct = nil, name = nil }
    pending_enemy_target = { visible = false }
    FlushPending()
end

Events.SubscribeRemote("FNV:UI:SetMode", function(payload)
    pending_mode = payload
    current_mode = (payload and payload.mode) or "gameplay"
    if current_mode ~= "gameplay" then
        SendEnemyTarget(false)
    end

    -- focus côté client (optionnel mais utile)
    if UI and (UI.IsValid and UI:IsValid()) then
        local mode = payload and payload.mode or "gameplay"
        if mode == "dialog" or mode == "shop" or mode == "container" then
            Input.SetInputEnabled(true)
            Input.SetMouseEnabled(true)
            UI:SetFocus()
        elseif mode == "inventory" then
            Input.SetInputEnabled(true)
            Input.SetMouseEnabled(true)
            UI:SetFocus()
        else
            UI:RemoveFocus()
            Input.SetMouseEnabled(false)
            Input.SetInputEnabled(true)
        end
    end

    FlushPending()
end)


Events.SubscribeRemote("FNV:Dialog:Open", function(payload)
    print("[CLIENT] got Dialog:Open npc=" .. tostring(payload and payload.npc and payload.npc.id) ..
        " node=" .. tostring(payload and payload.node and payload.node.id))
    print("[FNV] Remote Dialog:Open npc=" .. tostring(payload and payload.npc and payload.npc.id) ..
        " node=" .. tostring(payload and payload.node and payload.node.id))

    -- Force focus + mouse for dialog (safety if UI:SetMode was missed/late)
    if UI and (UI.IsValid and UI:IsValid()) then
        Input.SetInputEnabled(true)
        Input.SetMouseEnabled(true)
        UI:SetFocus()
    end

    -- Force first person while dialog is open
    ForceFirstPerson()

    pending_dialog_open = payload
    pending_dialog_close = nil
    FlushPending()
end)

Events.SubscribeRemote("FNV:Dialog:Close", function(payload)
    print("[FNV] Remote Dialog:Close")
    pending_dialog_close = payload or { open = false }
    pending_dialog_open = nil

    -- Restore camera after dialog
    RestoreCameraMode()
    FlushPending()
end)

Events.SubscribeRemote("FNV:Shop:Open", function(payload)
    print("[FNV] Remote Shop:Open vendor=" .. tostring(payload and payload.vendor and payload.vendor.name))
    -- Force focus + mouse for shop (safety if UI:SetMode was missed/late)
    if UI and (UI.IsValid and UI:IsValid()) then
        Input.SetInputEnabled(true)
        Input.SetMouseEnabled(true)
        UI:SetFocus()
    end
    pending_shop_open = payload
    pending_shop_close = nil
    FlushPending()
end)

Events.SubscribeRemote("FNV:Shop:Close", function(payload)
    print("[FNV] Remote Shop:Close")
    pending_shop_close = payload or { open = false }
    pending_shop_open = nil
    ResetGameplayInput()
    FlushPending()
end)

Events.SubscribeRemote("FNV:Inv:Open", function(payload)
    current_mode = "inventory"
    inv_open = true
    if UI and (UI.IsValid and UI:IsValid()) then
        Input.SetInputEnabled(true)
        Input.SetMouseEnabled(true)
        UI:SetFocus()
    end
    pending_inv_open = payload
    pending_inv_close = nil
    FlushPending()
end)

Events.SubscribeRemote("FNV:Inv:Close", function(payload)
    current_mode = "gameplay"
    inv_open = false
    pending_inv_close = payload or { open = false }
    pending_inv_open = nil
    ResetGameplayInput()
    FlushPending()
end)

Events.SubscribeRemote("FNV:Container:Open", function(payload)
    pending_container_open = payload
    pending_container_close = nil
    FlushPending()
end)

Events.SubscribeRemote("FNV:Container:Close", function(payload)
    pending_container_close = payload or { open = false }
    pending_container_open = nil
    FlushPending()
end)

Events.SubscribeRemote("FNV:Container:TransferOpen", function(payload)
    pending_container_transfer_open = payload
    current_container_transfer_open_id = payload and payload.container and payload.container.id or current_container_transfer_open_id
    pending_container_close = { open = false }
    pending_container_open = nil
    pending_hud_visible = false
    pending_interact_prompt = { show = false }
    FlushPending()
end)

Events.SubscribeRemote("FNV:Container:TransferClose", function(payload)
    pending_container_transfer_close = payload or { open = false }
    current_container_transfer_open_id = nil
    pending_hud_visible = true
    pending_interact_prompt = { show = false }
    FlushPending()
end)



Events.SubscribeRemote("FNV:HUD:Notify", function(payload)
    if not UI then return end
    UI:CallEvent("HUD:Notify", payload)
end)

Events.SubscribeRemote("FNV:HUD:Sync", function(state)
    pending_hud_state = state
    FlushPending()
end)

Events.SubscribeRemote("FNV:Weapon:HolsterState", function(payload)
    weapon_holstered = payload and payload.holstered == true
end)


local NPCS = {} -- id -> { name, loc=Vector }
local LOOTS = {} -- id -> { name, loc=Vector, item_id }
local CONTAINERS = {} -- id -> { name, loc=Vector }
local current_npc_id = nil
local current_loot_id = nil
local current_container_id = nil

local last_sent = { show = false, id = nil }
local function SendPromptState(show, npc_id)
    if last_sent.show == show and last_sent.id == npc_id then
        return
    end
    last_sent.show = show
    last_sent.id = npc_id
    Events.CallRemote("FNV:NPC:Prompt", { show = show, npc_id = npc_id })
end

local last_loot_sent = { show = false, id = nil }
local function SendLootPrompt(show, loot_id)
    if last_loot_sent.show == show and last_loot_sent.id == loot_id then
        return
    end
    last_loot_sent.show = show
    last_loot_sent.id = loot_id
    Events.CallRemote("FNV:Loot:Prompt", { show = show, loot_id = loot_id })
end

local last_container_sent = { show = false, id = nil }
local function SendContainerPrompt(show, container_id)
    if last_container_sent.show == show and last_container_sent.id == container_id then
        return
    end
    last_container_sent.show = show
    last_container_sent.id = container_id
    Events.CallRemote("FNV:Container:Prompt", { show = show, container_id = container_id })
end

Events.SubscribeRemote("FNV:NPC:List", function(payload)
    NPCS = {}
    if not payload or not payload.npcs then return end

    for _, n in ipairs(payload.npcs) do
        NPCS[n.id] = {
            name = n.name,
            loc = Vector(n.x, n.y, n.z),
            hostile = n.hostile == true,
            hp = tonumber(n.hp) or 0,
            hp_max = tonumber(n.hp_max) or 100
        }
    end
end)

Events.SubscribeRemote("FNV:NPC:Update", function(payload)
    local id = payload and payload.id
    if not id then return end
    NPCS[id] = NPCS[id] or { name = payload.name or id }
    local npc = NPCS[id]
    if payload.name then npc.name = payload.name end
    if payload.hostile ~= nil then npc.hostile = payload.hostile == true end
    if payload.hp ~= nil then npc.hp = tonumber(payload.hp) or 0 end
    if payload.hp_max ~= nil then npc.hp_max = tonumber(payload.hp_max) or 100 end
end)

Events.SubscribeRemote("FNV:Loot:List", function(payload)
    LOOTS = {}
    if not payload or not payload.loot then return end
    for _, l in ipairs(payload.loot) do
        LOOTS[l.id] = {
            name = l.name,
            item_id = l.item_id,
            loc = Vector(l.x, l.y, l.z)
        }
    end
end)

Events.SubscribeRemote("FNV:Loot:Update", function(payload)
    local id = payload and payload.id
    if not id then return end
    LOOTS[id] = LOOTS[id] or { name = payload.name or "Loot" }
    local loot = LOOTS[id]
    if payload.name then loot.name = payload.name end
    if payload.item_id then loot.item_id = payload.item_id end
    if payload.x and payload.y and payload.z then
        loot.loc = Vector(payload.x, payload.y, payload.z)
    end
end)

Events.SubscribeRemote("FNV:Loot:Remove", function(payload)
    local id = payload and payload.id
    if not id then return end
    LOOTS[id] = nil
    if current_loot_id == id then
        current_loot_id = nil
        SendLootPrompt(false, nil)
    end
end)

Events.SubscribeRemote("FNV:Container:List", function(payload)
    CONTAINERS = {}
    if not payload or not payload.containers then return end
    for _, c in ipairs(payload.containers) do
        CONTAINERS[c.id] = {
            name = c.name,
            loc = Vector(c.x, c.y, c.z)
        }
    end
end)

Events.SubscribeRemote("FNV:Container:Update", function(payload)
    local id = payload and payload.id
    if not id then return end
    CONTAINERS[id] = CONTAINERS[id] or { name = payload.name or "Container" }
    local cont = CONTAINERS[id]
    if payload.name then cont.name = payload.name end
    if payload.x and payload.y and payload.z then
        cont.loc = Vector(payload.x, payload.y, payload.z)
    end
end)

Events.SubscribeRemote("FNV:Container:Remove", function(payload)
    local id = payload and payload.id
    if not id then return end
    CONTAINERS[id] = nil
    if current_container_id == id then
        current_container_id = nil
        SendContainerPrompt(false, nil)
    end
end)

local function Dot2(a, b) return a.X*b.X + a.Y*b.Y end
local function Normalize2(v)
    local len = math.sqrt(v.X*v.X + v.Y*v.Y)
    if len < 0.0001 then return nil end
    return Vector(v.X/len, v.Y/len, 0)
end

Timer.SetInterval(function()
    local PROMPT_RANGE = 300
    local ENEMY_TARGET_RANGE = 1000
    local LOOT_RANGE = 250
    local CONTAINER_RANGE = 260
    local LOOT_DOT_THRESHOLD = 0.80
    local viewport_center = Viewport.GetViewportSize() / 2
    local v3 = Viewport.DeprojectScreenToWorld(viewport_center)
    if not v3 or not v3.Position or not v3.Direction then
        return
    end

    local cam_pos = v3.Position
    local cam_dir = v3.Direction

    -- 2D forward (ignore vertical)
    local f2 = Normalize2(Vector(cam_dir.X, cam_dir.Y, 0))
    if not f2 then
        current_npc_id = nil
        current_loot_id = nil
        SendPromptState(false, nil)
        SendLootPrompt(false, nil)
        return
    end

    if current_mode ~= "gameplay" then
        current_npc_id = nil
        current_loot_id = nil
        current_container_id = nil
        SendPromptState(false, nil)
        SendLootPrompt(false, nil)
        SendContainerPrompt(false, nil)
        SendEnemyTarget(false)
        return
    end

    local best_id = nil
    local best_dot = -1
    local best_dist = 999999
    local best_loot_id = nil
    local best_loot_dot = -1
    local best_loot_dist = 999999
    local best_container_id = nil
    local best_container_dot = -1
    local best_container_dist = 999999
    local best_enemy_id = nil
    local best_enemy_dot = -1
    local best_enemy_dist = 999999

    for id, npc in pairs(NPCS) do
        if npc.loc then
            -- vise le torse
            local target = npc.loc + Vector(0, 0, 90)
            local to = target - cam_pos
            local dist = to:Size()

            local max_range = npc.hostile and ENEMY_TARGET_RANGE or PROMPT_RANGE
            if dist < max_range then
                local d2 = Normalize2(Vector(to.X, to.Y, 0))
                if d2 then
                    local dot = Dot2(f2, d2)
                    if (not npc.hostile) and dot > best_dot then
                        best_dot = dot
                        best_id = id
                        best_dist = dist
                    end
                    if npc.hostile and dot > best_enemy_dot then
                        best_enemy_dot = dot
                        best_enemy_id = id
                        best_enemy_dist = dist
                    end
                end
            end
        end
    end

    for id, loot in pairs(LOOTS) do
        if loot.loc then
            local target = loot.loc + Vector(0, 0, 30)
            local to = target - cam_pos
            local dist = to:Size()
            if dist < LOOT_RANGE then
                local d2 = Normalize2(Vector(to.X, to.Y, 0))
                if d2 then
                    local dot = Dot2(f2, d2)
                    if dot > best_loot_dot then
                        best_loot_dot = dot
                        best_loot_id = id
                        best_loot_dist = dist
                    end
                end
            end
        end
    end

    for id, cont in pairs(CONTAINERS) do
        if cont.loc then
            local target = cont.loc + Vector(0, 0, 30)
            local to = target - cam_pos
            local dist = to:Size()
            if dist < CONTAINER_RANGE then
                local d2 = Normalize2(Vector(to.X, to.Y, 0))
                if d2 then
                    local dot = Dot2(f2, d2)
                    if dot > best_container_dot then
                        best_container_dot = dot
                        best_container_id = id
                        best_container_dist = dist
                    end
                end
            end
        end
    end

    local best_prompt_type = nil
    local best_prompt_id = nil
    local best_prompt_dot = -1
    local best_prompt_dist = 999999

    if best_id then
        best_prompt_type = "npc"
        best_prompt_id = best_id
        best_prompt_dot = best_dot
        best_prompt_dist = best_dist
    end

    if best_loot_id and best_loot_dot > best_prompt_dot then
        best_prompt_type = "loot"
        best_prompt_id = best_loot_id
        best_prompt_dot = best_loot_dot
        best_prompt_dist = best_loot_dist
    end

    if best_container_id and best_container_dot > best_prompt_dot then
        best_prompt_type = "container"
        best_prompt_id = best_container_id
        best_prompt_dot = best_container_dot
        best_prompt_dist = best_container_dist
    end

    if best_prompt_type == "loot" and best_prompt_dot > LOOT_DOT_THRESHOLD and best_prompt_dist < LOOT_RANGE then
        current_loot_id = best_prompt_id
        current_npc_id = nil
        current_container_id = nil
        SendLootPrompt(true, best_prompt_id)
        SendPromptState(false, nil)
    elseif best_prompt_type == "container" and best_prompt_dot > 0.85 and best_prompt_dist < CONTAINER_RANGE then
        current_container_id = best_prompt_id
        current_npc_id = nil
        current_loot_id = nil
        SendPromptState(false, nil)
        SendLootPrompt(false, nil)
    elseif best_prompt_type == "npc" and best_prompt_dot > 0.90 and best_prompt_dist < PROMPT_RANGE then
        current_npc_id = best_prompt_id
        current_loot_id = nil
        current_container_id = nil
        SendPromptState(true, best_prompt_id)
        SendLootPrompt(false, nil)
    else
        current_npc_id = nil
        current_loot_id = nil
        current_container_id = nil
        SendPromptState(false, nil)
        SendLootPrompt(false, nil)
    end

    if current_container_id and current_container_id ~= current_container_open_id then
        current_container_open_id = current_container_id
        Events.CallRemote("FNV:Container:OpenRequest", { container_id = current_container_id })
    elseif not current_container_id and current_container_open_id then
        current_container_open_id = nil
        Events.CallRemote("FNV:Container:CloseRequest", {})
        pending_container_close = { open = false }
        pending_container_open = nil
        FlushPending()
    end

    if best_enemy_id and best_enemy_dot > 0.90 and best_enemy_dist < ENEMY_TARGET_RANGE then
        local npc = NPCS[best_enemy_id]
        local hp = npc and tonumber(npc.hp) or 0
        local hp_max = npc and tonumber(npc.hp_max) or 100
        if hp <= 0 then
            SendEnemyTarget(false)
            return
        end
        local hp_pct = 0
        if hp_max > 0 then
            hp_pct = math.floor((hp / hp_max) * 100 + 0.5)
        end
        if hp_pct < 0 then hp_pct = 0 end
        if hp_pct > 100 then hp_pct = 100 end
        SendEnemyTarget(true, npc and npc.name or best_enemy_id, hp_pct, best_enemy_id)
    else
        SendEnemyTarget(false)
    end
end, 100)

local last_yaw = nil
Timer.SetInterval(function()
    if not ui_ready or not UI then return end
    local ply = Client.GetLocalPlayer()
    if not ply then return end
    local char = ply:GetControlledCharacter()
    if not char then return end
    local rot = char:GetControlRotation()
    if not rot then return end
    local yaw = rot.Yaw
    if yaw == nil then return end
    if last_yaw == nil or math.abs(yaw - last_yaw) > 0.5 then
        last_yaw = yaw
        UI:CallEvent("HUD:SetHeading", yaw)
    end
end, 100)

Input.Subscribe("KeyPress", function(key_name)
    if type(key_name) ~= "string" then return end
    if current_mode == "shop" and key_name:upper() == "BACKSPACE" then
        Events.CallRemote("FNV:Shop:CloseRequest", {})
        return
    end
    if current_mode ~= "gameplay" then return end
    if key_name:upper() ~= "E" then return end
    if current_loot_id then
        Events.CallRemote("FNV:Loot:Pickup", { loot_id = current_loot_id })
        return
    end
    if not current_npc_id then return end

    Events.CallRemote("FNV:NPC:Interact", { npc_id = current_npc_id })
end)

local sprint_active = false
local sprint_locked = false
local mouse_left_down = false
local weapon_holstered = false
local r_hold = { pressed = false, fired = false, start = nil }

local function SendSprint(active)
    Events.CallRemote("FNV:AP:Sprint", { active = active })
end

local function SendHolsterToggle()
    Events.CallRemote("FNV:Weapon:ToggleHolster", {})
end

local function SendHolsterSet(holstered)
    Events.CallRemote("FNV:Weapon:SetHolstered", { holstered = holstered == true })
end

Input.Subscribe("KeyPress", function(key_name)
    if type(key_name) ~= "string" then return end
    if current_mode ~= "gameplay" then return end

    local key = key_name:upper()
    if key == "R" and current_container_id then
        Events.CallRemote("FNV:Container:TransferOpenRequest", { container_id = current_container_id })
        return
    end
    if key == "R" then
        if not r_hold.pressed then
            r_hold.pressed = true
            r_hold.fired = false
            r_hold.start = os.clock()
        end
        return
    end
    if key == "LEFTSHIFT" or key == "SHIFT" then
        if sprint_locked then return end
        if not sprint_active then
            sprint_active = true
            SendSprint(true)
        end
        return
    end

    if key == "LEFTMOUSEBUTTON" or key == "LEFTMOUSE" or key == "MOUSELEFT" then
        if weapon_holstered then
            SendHolsterSet(false)
            return
        end
        Events.CallRemote("FNV:AP:Punch", {})
        return
    end
end)


Events.SubscribeRemote("FNV:Interact:Prompt", function(payload)
    pending_interact_prompt = payload
    FlushPending()
end)

Input.Subscribe("KeyRelease", function(key_name)
    if type(key_name) ~= "string" then return end
    if current_mode ~= "gameplay" then return end

    local key = key_name:upper()
    if key == "R" then
        r_hold.pressed = false
        r_hold.fired = false
        r_hold.start = nil
        return
    end
    if key == "LEFTSHIFT" or key == "SHIFT" then
        if sprint_active then
            sprint_active = false
            SendSprint(false)
        end
        return
    end
end)

Events.SubscribeRemote("FNV:AP:SprintLock", function(payload)
    sprint_locked = payload and payload.locked == true
    if sprint_locked and sprint_active then
        sprint_active = false
        SendSprint(false)
    end
end)

Timer.SetInterval(function()
    if current_mode ~= "gameplay" then return end
    if Input and Input.IsKeyDown then
        local r_down = Input.IsKeyDown("R")
        if r_down and not r_hold.pressed then
            r_hold.pressed = true
            r_hold.fired = false
            r_hold.start = os.clock()
        elseif r_down and r_hold.pressed and not r_hold.fired then
            local elapsed = os.clock() - (r_hold.start or os.clock())
            if elapsed >= 0.35 then
                r_hold.fired = true
                SendHolsterToggle()
            end
        elseif (not r_down) and r_hold.pressed then
            if not r_hold.fired and not weapon_holstered then
                Events.CallRemote("FNV:Weapon:ReloadRequest", {})
            end
            r_hold.pressed = false
            r_hold.fired = false
            r_hold.start = nil
        end

        local down = Input.IsKeyDown("LeftShift") or Input.IsKeyDown("Shift")
        if down and not sprint_locked and not sprint_active then
            sprint_active = true
            SendSprint(true)
        elseif (not down) and sprint_active then
            sprint_active = false
            SendSprint(false)
        end
    end

    if Input and Input.IsMouseButtonDown then
        local down = Input.IsMouseButtonDown("LeftMouseButton") or Input.IsMouseButtonDown("LeftMouse")
        if down and not mouse_left_down then
            mouse_left_down = true
            if weapon_holstered then
                SendHolsterSet(false)
            else
                Events.CallRemote("FNV:AP:Punch", {})
            end
        elseif (not down) and mouse_left_down then
            mouse_left_down = false
        end
    end
end, 100)
