LOOT = LOOT or {}
LOOT.List = LOOT.List or {}
LOOT.NEXT_ID = LOOT.NEXT_ID or 1

local INTERACT_RANGE = 300

local function DistSq(a, b)
    local dx = a.X - b.X
    local dy = a.Y - b.Y
    local dz = a.Z - b.Z
    return dx * dx + dy * dy + dz * dz
end

local function GetDropMesh(def)
    if not def then return "nanos-world::SM_Cube" end
    local function IsSkeletal(mesh)
        return type(mesh) == "string" and mesh:find("::SK_")
    end
    if def.drop_mesh and not IsSkeletal(def.drop_mesh) then return def.drop_mesh end
    if def.world_mesh and not IsSkeletal(def.world_mesh) then return def.world_mesh end
    if def.mesh and not IsSkeletal(def.mesh) then return def.mesh end
    if def.weapon and def.weapon.mesh and not IsSkeletal(def.weapon.mesh) then return def.weapon.mesh end
    if def.visual and def.visual.mesh and not IsSkeletal(def.visual.mesh) then return def.visual.mesh end
    return "nanos-world::SM_Cube"
end

local function GetDropLocation(player)
    local char = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if not char or not char.IsValid or not char:IsValid() then return nil end
    local loc = char:GetLocation()
    local rot = char:GetRotation()
    if rot and rot.GetForwardVector then
        local fwd = rot:GetForwardVector()
        return loc + (fwd * 90) + Vector(0, 0, 20)
    end
    return loc + Vector(0, 0, 20)
end

local function BuildLootPayload(id, data, include_loc)
    if not data then return nil end
    local payload = {
        id = id,
        item_id = data.item_id,
        name = data.name,
        qty = data.qty
    }
    if include_loc and data.prop and data.prop.IsValid and data.prop:IsValid() then
        local loc = data.prop:GetLocation()
        payload.x = loc.X
        payload.y = loc.Y
        payload.z = loc.Z
    end
    return payload
end

function LOOT.BroadcastUpdate(loot_id)
    local data = loot_id and LOOT.List[loot_id]
    if not data then return end
    local payload = BuildLootPayload(loot_id, data, true)
    for _, player in pairs(Player.GetAll()) do
        Events.CallRemote("FNV:Loot:Update", player, payload)
    end
end

function LOOT.BroadcastRemove(loot_id)
    for _, player in pairs(Player.GetAll()) do
        Events.CallRemote("FNV:Loot:Remove", player, { id = loot_id })
    end
end

function LOOT.GetAllForClient()
    local out = {}
    for id, data in pairs(LOOT.List) do
        local payload = BuildLootPayload(id, data, true)
        if payload then
            out[#out + 1] = payload
        end
    end
    return out
end

function LOOT.Remove(loot_id)
    local data = loot_id and LOOT.List[loot_id]
    if not data then return end
    if data.prop and data.prop.IsValid and data.prop:IsValid() then
        data.prop:Destroy()
    end
    LOOT.List[loot_id] = nil
    LOOT.BroadcastRemove(loot_id)
end

function LOOT.SpawnDrop(player, item_id, qty, instance_data)
    local def = ITEMS and ITEMS.Get and ITEMS.Get(item_id)
    if not def then return false, "unknown_item" end
    local loc = GetDropLocation(player)
    if not loc then return false, "no_character" end

    local mesh = GetDropMesh(def)
    local prop = Prop(loc, Rotator(0, 0, 0), mesh)
    if not prop or not prop.IsValid or not prop:IsValid() then
        return false, "spawn_failed"
    end

    local id = LOOT.NEXT_ID
    LOOT.NEXT_ID = id + 1

    LOOT.List[id] = {
        id = id,
        item_id = item_id,
        qty = qty or 1,
        name = def.name or item_id,
        instance = instance_data,
        prop = prop
    }

    if prop.Subscribe then
        prop:Subscribe("Destroy", function()
            if LOOT.List[id] then
                LOOT.List[id] = nil
                LOOT.BroadcastRemove(id)
            end
        end)
    end

    LOOT.BroadcastUpdate(id)
    return true, id
end

function LOOT.DropFromPlayer(player, state, item_id, amount, instance_id)
    if not state or not state.inventory then return false, "no_inventory" end

    local def = ITEMS and ITEMS.Get and ITEMS.Get(item_id)
    if not def then return false, "unknown_item" end

    local instance_data = nil
    if instance_id and state.inventory.instances then
        local inst = state.inventory.instances[instance_id]
        if not inst then return false, "invalid_instance" end
        instance_data = {
            condition = inst.condition,
            mods = inst.mods,
            custom_name = inst.custom_name,
            extra = inst.extra
        }
    end

    local qty = tonumber(amount) or 1
    if instance_id then qty = 1 end

    local ok, err = INV.Remove(state.inventory, item_id, qty, instance_id)
    if not ok then return false, err end

    local spawned, spawn_err = LOOT.SpawnDrop(player, item_id, qty, instance_data)
    if not spawned then
        INV.Add(state.inventory, item_id, qty, instance_data)
        return false, spawn_err or "spawn_failed"
    end

    return true
end

local function SaveInventoryState(player, state)
    local player_id = PLAYERS and PLAYERS.GetID and PLAYERS.GetID(player)
    if not player_id or not state then return end
    if INV_STORE and INV_STORE.Save then
        INV_STORE.Save(player_id, state.inventory)
    end
end

local function RefreshInventory(player, state)
    if not INV_SERVICE or not INV_SERVICE.SESSIONS then return end
    if not INV_SERVICE.SESSIONS[player] then return end
    local payload = INV and INV.BuildPayload and INV.BuildPayload(state)
    if payload then
        Events.CallRemote("FNV:Inv:Open", player, payload)
    end
end

Events.SubscribeRemote("FNV:Loot:RequestList", function(player)
    local list = LOOT.GetAllForClient()
    Events.CallRemote("FNV:Loot:List", player, { loot = list })
end)

Events.SubscribeRemote("FNV:Loot:Prompt", function(player, payload)
    local show = payload and payload.show
    local loot_id = payload and payload.loot_id

    if not show then
        return Events.CallRemote("FNV:Interact:Prompt", player, { show = false })
    end

    local data = loot_id and LOOT.List[loot_id]
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
        action = "RAMASSER",
        name = data.name or data.item_id
    })
end)

Events.SubscribeRemote("FNV:Loot:Pickup", function(player, payload)
    local loot_id = payload and payload.loot_id
    if not loot_id then return end

    local data = LOOT.List[loot_id]
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

    local ok, err = INV.Add(state.inventory, data.item_id, data.qty or 1, data.instance)
    if not ok then
        if HUD_NOTIFY and HUD_NOTIFY.Send then
            HUD_NOTIFY.Send(player, "Ramassage impossible: " .. tostring(err), 2000)
        end
        return
    end

    LOOT.Remove(loot_id)
    SaveInventoryState(player, state)
    RefreshInventory(player, state)
    if HUD_SYNC and HUD_SYNC.Send then
        HUD_SYNC.Send(player, state)
    end
    if HUD_NOTIFY and HUD_NOTIFY.Send then
        HUD_NOTIFY.Send(player, "Ramassé : " .. tostring(data.name or data.item_id), 1500)
    end

    Events.CallRemote("FNV:Interact:Prompt", player, { show = false })
end)

local function BroadcastAllPositions()
    for id, data in pairs(LOOT.List) do
        if data and data.prop and data.prop.IsValid and data.prop:IsValid() then
            LOOT.BroadcastUpdate(id)
        end
    end
end

Timer.SetInterval(BroadcastAllPositions, 1000)
