CONTAINER = CONTAINER or {}
CONTAINER.List = CONTAINER.List or {}
CONTAINER.SESSIONS = CONTAINER.SESSIONS or {}

local INTERACT_RANGE = 300

local function DistSq(a, b)
    local dx = a.X - b.X
    local dy = a.Y - b.Y
    local dz = a.Z - b.Z
    return dx * dx + dy * dy + dz * dz
end

local function BuildPayload(id, data, include_loc)
    if not data then return nil end
    local payload = {
        id = id,
        name = data.name or id
    }
    if include_loc and data.prop and data.prop.IsValid and data.prop:IsValid() then
        local loc = data.prop:GetLocation()
        payload.x = loc.X
        payload.y = loc.Y
        payload.z = loc.Z
    end
    return payload
end

local function BuildItemsPayload(inv)
    local out = {}
    local entries = INV.GetEntries(inv)
    for _, entry in ipairs(entries) do
        local def = entry.def or (ITEMS and ITEMS.Get and ITEMS.Get(entry.base_id))
        if def then
            local cnd = entry.condition or def.cnd or 100
            local value = INV and INV.CalcValue and INV.CalcValue(def, cnd) or def.value
            out[#out + 1] = {
                item_id = entry.base_id,
                name = entry.custom_name or def.name or entry.base_id,
                category = def.category,
                qty = entry.qty or 1,
                stackable = entry.stackable == true,
                instance_id = entry.instance_id,
                cnd = cnd,
                wg = def.wg or 0,
                value = value,
                icon = def.icon,
                info = def.info,
                desc = def.desc
            }
        end
    end
    return out
end

local function BuildTransferPayload(container_id, data, state)
    if not data or not data.inventory or not state or not state.inventory then return nil end
    local container_weight = INV.CalcWeight(data.inventory)
    local player_weight = INV.CalcWeight(state.inventory)
    local player_max = tonumber(state.carry_weight_max) or 0
    return {
        open = true,
        mode = "transfer",
        container = {
            id = container_id,
            name = data.name or container_id,
            weight = container_weight
        },
        player = {
            name = "OBJETS",
            weight = {
                current = player_weight,
                max = player_max
            }
        },
        container_items = BuildItemsPayload(data.inventory),
        player_items = BuildItemsPayload(state.inventory),
        selected = { side = "left", index = 0 }
    }
end

local function SetMode(player, mode)
    Events.CallRemote("FNV:UI:SetMode", player, { mode = mode })
end

local function FreezePlayerForContainer(player, freeze)
    local char = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if not char or not char.IsValid or not char:IsValid() then return end
    if char.SetInputEnabled then
        char:SetInputEnabled(not freeze)
    end
end

local function SendOpen(player, id, data, mode)
    if not data or not data.inventory then return end
    local payload = {
        open = true,
        mode = mode,
        container = { id = id, name = data.name or id },
        items = BuildItemsPayload(data.inventory),
        selected = { index = 0 }
    }
    Events.CallRemote("FNV:Container:Open", player, payload)
end

local function SendClose(player)
    Events.CallRemote("FNV:Container:Close", player, { open = false })
end

local function SendTransferClose(player)
    Events.CallRemote("FNV:Container:TransferClose", player, { open = false })
end

function CONTAINER.BroadcastUpdate(id)
    local data = CONTAINER.List[id]
    if not data then return end
    local payload = BuildPayload(id, data, true)
    for _, player in pairs(Player.GetAll()) do
        Events.CallRemote("FNV:Container:Update", player, payload)
    end
end

function CONTAINER.BroadcastRemove(id)
    for _, player in pairs(Player.GetAll()) do
        Events.CallRemote("FNV:Container:Remove", player, { id = id })
    end
end

function CONTAINER.GetAllForClient()
    local out = {}
    for id, data in pairs(CONTAINER.List) do
        local payload = BuildPayload(id, data, true)
        if payload then
            out[#out + 1] = payload
        end
    end
    return out
end

function CONTAINER.Spawn(id, location, rot, name, mesh)
    if not id then return false end
    if CONTAINER.List[id] then return true end

    rot = rot or Rotator(0, 0, 0)
    mesh = mesh or "nanos-world::SM_Crate_07"

    local prop = StaticMesh(location, rot, mesh)
    if not prop or not prop.IsValid or not prop:IsValid() then
        return false
    end

    if prop.SetSimulatePhysics then
        prop:SetSimulatePhysics(false)
    end
    if prop.SetGravityEnabled then
        prop:SetGravityEnabled(false)
    end

    local inv = (CONTAINER_STORE and CONTAINER_STORE.Load and CONTAINER_STORE.Load(id)) or INV.New()

    CONTAINER.List[id] = {
        id = id,
        name = name or id,
        prop = prop,
        inventory = inv
    }

    if prop.Subscribe then
        prop:Subscribe("Destroy", function()
            if CONTAINER.List[id] then
                CONTAINER.List[id] = nil
                CONTAINER.BroadcastRemove(id)
            end
        end)
    end

    CONTAINER.BroadcastUpdate(id)
    return true
end

local function SaveContainer(id, data)
    if not id or not data or not data.inventory then return end
    if CONTAINER_STORE and CONTAINER_STORE.Save then
        CONTAINER_STORE.Save(id, data.inventory)
    end
end

local function MoveAllItems(container_inv, player_inv)
    local entries = INV.GetEntries(container_inv)
    if not entries or #entries == 0 then return 0 end

    local moved = 0
    for _, entry in ipairs(entries) do
        if entry.type == "stack" then
            local qty = entry.qty or 0
            if qty > 0 then
                local ok = INV.Add(player_inv, entry.base_id, qty)
                if ok then
                    INV.Remove(container_inv, entry.base_id, qty)
                    moved = moved + qty
                end
            end
        else
            local instance_data = {
                condition = entry.condition,
                mods = entry.mods,
                custom_name = entry.custom_name,
                equipped = false,
                extra = entry.extra
            }
            local ok = INV.Add(player_inv, entry.base_id, 1, instance_data)
            if ok then
                INV.Remove(container_inv, entry.base_id, 1, entry.instance_id)
                moved = moved + 1
            end
        end
    end

    return moved
end

Events.SubscribeRemote("FNV:Container:RequestList", function(player)
    local list = CONTAINER.GetAllForClient()
    Events.CallRemote("FNV:Container:List", player, { containers = list })
end)

Events.SubscribeRemote("FNV:Container:Prompt", function(player, payload)
    local show = payload and payload.show
    local container_id = payload and payload.container_id

    if not show then
        return Events.CallRemote("FNV:Interact:Prompt", player, { show = false })
    end

    local data = container_id and CONTAINER.List[container_id]
    if not data or not data.prop or not data.prop.IsValid or not data.prop:IsValid() then
        return Events.CallRemote("FNV:Interact:Prompt", player, { show = false })
    end

    local pchar = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if pchar then
        local ppos = pchar:GetLocation()
        local npos = data.prop:GetLocation()
        if DistSq(ppos, npos) > (INTERACT_RANGE * INTERACT_RANGE) then
            return Events.CallRemote("FNV:Interact:Prompt", player, { show = false })
        end
    end

    Events.CallRemote("FNV:Interact:Prompt", player, {
        show = true,
        key = "E",
        action = "FOUILLER",
        name = data.name or container_id
    })
end)

Events.SubscribeRemote("FNV:Container:OpenRequest", function(player, payload)
    local container_id = payload and payload.container_id
    if not container_id then return end

    local data = CONTAINER.List[container_id]
    if not data or not data.prop or not data.prop.IsValid or not data.prop:IsValid() then return end

    local pchar = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if pchar then
        local ppos = pchar:GetLocation()
        local npos = data.prop:GetLocation()
        if DistSq(ppos, npos) > (INTERACT_RANGE * INTERACT_RANGE) then
            return
        end
    end

    SendOpen(player, container_id, data, nil)
end)

Events.SubscribeRemote("FNV:Container:CloseRequest", function(player, payload)
    SendClose(player)
end)

Events.SubscribeRemote("FNV:Container:TransferOpenRequest", function(player, payload)
    local container_id = payload and payload.container_id
    if not container_id then return end

    local data = CONTAINER.List[container_id]
    if not data or not data.prop or not data.prop.IsValid or not data.prop:IsValid() then return end

    local pchar = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if pchar then
        local ppos = pchar:GetLocation()
        local npos = data.prop:GetLocation()
        if DistSq(ppos, npos) > (INTERACT_RANGE * INTERACT_RANGE) then
            return
        end
    end

    CONTAINER.SESSIONS[player] = container_id
    FreezePlayerForContainer(player, true)
    SetMode(player, "container")

    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state or not state.inventory then return end

    local payload_out = BuildTransferPayload(container_id, data, state)
    if payload_out then
        Events.CallRemote("FNV:Container:TransferOpen", player, payload_out)
    end
end)

Events.SubscribeRemote("FNV:Container:TransferCloseRequest", function(player, payload)
    if CONTAINER.SESSIONS[player] then
        CONTAINER.SESSIONS[player] = nil
    end
    FreezePlayerForContainer(player, false)
    SetMode(player, "gameplay")
    SendTransferClose(player)
end)

Events.SubscribeRemote("FNV:Container:Interact", function(player, payload)
    local container_id = payload and payload.container_id
    if not container_id then return end

    local data = CONTAINER.List[container_id]
    if not data or not data.prop or not data.prop.IsValid or not data.prop:IsValid() then return end

    local pchar = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if pchar then
        local ppos = pchar:GetLocation()
        local npos = data.prop:GetLocation()
        if DistSq(ppos, npos) > (INTERACT_RANGE * INTERACT_RANGE) then
            return
        end
    end

    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state or not state.inventory then return end

    local moved = MoveAllItems(data.inventory, state.inventory)
    if HUD_NOTIFY and HUD_NOTIFY.Send then
        if moved > 0 then
            HUD_NOTIFY.Send(player, "Conteneur fouille (+ " .. tostring(moved) .. ")", 1500)
        else
            HUD_NOTIFY.Send(player, "Conteneur vide", 1500)
        end
    end

    if INV_STORE and INV_STORE.Save and PLAYERS and PLAYERS.GetID then
        local player_id = PLAYERS.GetID(player)
        if player_id then
            INV_STORE.Save(player_id, state.inventory)
        end
    end
    if INV_SERVICE and INV_SERVICE.SESSIONS and INV_SERVICE.SESSIONS[player] and INV.BuildPayload then
        Events.CallRemote("FNV:Inv:Open", player, INV.BuildPayload(state))
    end
    if HUD_SYNC and HUD_SYNC.Send then
        HUD_SYNC.Send(player, state)
    end

    Events.CallRemote("FNV:Interact:Prompt", player, { show = false })
end)

Events.SubscribeRemote("FNV:Container:Take", function(player, payload)
    local container_id = payload and payload.container_id
    local item_id = payload and payload.item_id
    local instance_id = payload and payload.instance_id
    if not container_id or not item_id then return end

    local data = CONTAINER.List[container_id]
    if not data or not data.inventory then return end

    local pchar = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if pchar then
        local ppos = pchar:GetLocation()
        local npos = data.prop and data.prop.GetLocation and data.prop:GetLocation()
        if npos and DistSq(ppos, npos) > (INTERACT_RANGE * INTERACT_RANGE) then
            return
        end
    end

    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state or not state.inventory then return end

    local instance_data = nil
    if instance_id and data.inventory.instances then
        local inst = data.inventory.instances[instance_id]
        if not inst then return end
        instance_data = {
            condition = inst.condition,
            mods = inst.mods,
            custom_name = inst.custom_name,
            extra = inst.extra
        }
    end

    local ok_add = INV.Add(state.inventory, item_id, 1, instance_data)
    if not ok_add then return end
    local ok_rem = INV.Remove(data.inventory, item_id, 1, instance_id)
    if not ok_rem then
        INV.Remove(state.inventory, item_id, 1, instance_data)
        return
    end

    SaveContainer(container_id, data)

    if INV_STORE and INV_STORE.Save and PLAYERS and PLAYERS.GetID then
        local player_id = PLAYERS.GetID(player)
        if player_id then
            INV_STORE.Save(player_id, state.inventory)
        end
    end
    if HUD_SYNC and HUD_SYNC.Send then
        HUD_SYNC.Send(player, state)
    end
    if INV_SERVICE and INV_SERVICE.SESSIONS and INV_SERVICE.SESSIONS[player] and INV.BuildPayload then
        Events.CallRemote("FNV:Inv:Open", player, INV.BuildPayload(state))
    end

    SendOpen(player, container_id, data, nil)
end)

Events.SubscribeRemote("FNV:Container:TransferMove", function(player, payload)
    local container_id = payload and payload.container_id
    local item_id = payload and payload.item_id
    local instance_id = payload and payload.instance_id
    local side = payload and payload.side or "left"
    local index = payload and payload.index
    if not container_id then return end

    local data = CONTAINER.List[container_id]
    if not data or not data.inventory then return end
    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state or not state.inventory then return end

    local from_container = (side == "left" or side == "container")
    local from_inv = from_container and data.inventory or state.inventory
    local to_inv = from_container and state.inventory or data.inventory

    if not item_id and index ~= nil then
        local list = BuildItemsPayload(from_inv)
        local idx = tonumber(index)
        if idx ~= nil then
            idx = idx + 1
            local entry = list[idx]
            if entry then
                item_id = entry.item_id
                instance_id = instance_id or entry.instance_id
            end
        end
    end
    if not item_id then return end

    local instance_data = nil
    if instance_id and from_inv.instances then
        local inst = from_inv.instances[instance_id]
        if not inst then return end
        instance_data = {
            condition = inst.condition,
            mods = inst.mods,
            custom_name = inst.custom_name,
            extra = inst.extra
        }
    end

    local ok_add = INV.Add(to_inv, item_id, 1, instance_data)
    if not ok_add then return end
    local ok_rem = INV.Remove(from_inv, item_id, 1, instance_id)
    if not ok_rem then
        INV.Remove(to_inv, item_id, 1, instance_data)
        return
    end

    SaveContainer(container_id, data)

    if INV_STORE and INV_STORE.Save and PLAYERS and PLAYERS.GetID then
        local player_id = PLAYERS.GetID(player)
        if player_id then
            INV_STORE.Save(player_id, state.inventory)
        end
    end
    if HUD_SYNC and HUD_SYNC.Send then
        HUD_SYNC.Send(player, state)
    end

    local payload_out = BuildTransferPayload(container_id, data, state)
    if payload_out then
        Events.CallRemote("FNV:Container:TransferOpen", player, payload_out)
    end
end)

Events.SubscribeRemote("FNV:Container:TransferTakeAll", function(player, payload)
    local container_id = payload and payload.container_id
    if not container_id then return end

    local data = CONTAINER.List[container_id]
    if not data or not data.inventory then return end
    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state or not state.inventory then return end

    MoveAllItems(data.inventory, state.inventory)

    SaveContainer(container_id, data)

    if INV_STORE and INV_STORE.Save and PLAYERS and PLAYERS.GetID then
        local player_id = PLAYERS.GetID(player)
        if player_id then
            INV_STORE.Save(player_id, state.inventory)
        end
    end
    if HUD_SYNC and HUD_SYNC.Send then
        HUD_SYNC.Send(player, state)
    end

    local payload_out = BuildTransferPayload(container_id, data, state)
    if payload_out then
        Events.CallRemote("FNV:Container:TransferOpen", player, payload_out)
    end
end)

Player.Subscribe("Destroy", function(player)
    if CONTAINER.SESSIONS[player] then
        CONTAINER.SESSIONS[player] = nil
    end
    FreezePlayerForContainer(player, false)
end)
