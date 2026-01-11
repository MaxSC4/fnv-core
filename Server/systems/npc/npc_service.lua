NPC = NPC or {}
NPC.List = NPC.List or {} -- npc_id -> { character, name }

local INTERACT_RANGE = 300

local function DistSq(a, b)
    local dx = a.X - b.X
    local dy = a.Y - b.Y
    local dz = a.Z - b.Z
    return dx*dx + dy*dy + dz*dz
end

local function Notify(player, text, ms)
    Events.CallRemote("FNV:HUD:Notify", player, { text = tostring(text), ms = ms or 2000 })
end

function NPC.DespawnAll()
    for id, data in pairs(NPC.List) do
        if data.character and data.character.IsValid and data.character:IsValid() then
            data.character:Destroy()
        end
        NPC.List[id] = nil
    end
    LOG.Info("[NPC] DespawnAll done")
end

function NPC.Spawn(npc_id, location, rot, display_name)
    rot = rot or Rotator(0, 0, 0)
    display_name = display_name or npc_id

    -- respawn-safe
    if NPC.List[npc_id] and NPC.List[npc_id].character and NPC.List[npc_id].character:IsValid() then
        return
    end

    local npc = Character(location, rot, "nanos-world::SK_Mannequin")

    NPC.List[npc_id] = {
        character = npc,
        name = display_name,
        hostile = false
    }

    LOG.Info("[NPC] Spawned " .. npc_id .. " (" .. display_name .. ")")
end

function NPC.Register(npc_id, character, display_name)
    if not npc_id or not character or not character.IsValid or not character:IsValid() then
        return false
    end
    NPC.List[npc_id] = {
        character = character,
        name = display_name or npc_id,
        hostile = false
    }
    NPC.BroadcastUpdate(npc_id)
    return true
end

function NPC.Unregister(npc_id)
    local data = npc_id and NPC.List[npc_id]
    if not data then return end
    if data.character and data.character.IsValid and data.character:IsValid() then
        data.character:Destroy()
    end
    NPC.List[npc_id] = nil
end

local function BuildNPCPayload(npc_id, data, include_loc)
    local payload = {
        id = npc_id,
        name = data and data.name or npc_id,
        hostile = data and data.hostile == true,
        hp = data and data.hp,
        hp_max = data and data.max_hp
    }
    if include_loc and data and data.character and data.character.IsValid and data.character:IsValid() then
        local loc = data.character:GetLocation()
        payload.x = loc.X
        payload.y = loc.Y
        payload.z = loc.Z
    end
    return payload
end

function NPC.BroadcastUpdate(npc_id)
    local data = npc_id and NPC.List[npc_id]
    if not data then return end
    local payload = BuildNPCPayload(npc_id, data, false)
    for _, player in pairs(Player.GetAll()) do
        Events.CallRemote("FNV:NPC:Update", player, payload)
    end
end

function NPC.SetHostile(npc_id, hostile)
    local data = npc_id and NPC.List[npc_id]
    if not data then return end
    data.hostile = hostile == true
    NPC.BroadcastUpdate(npc_id)
end

local function ResolvePlayerFromInstigator(instigator)
    if not instigator or type(instigator) ~= "table" then return nil end
    if instigator.GetControlledCharacter then
        return instigator
    end
    if instigator.GetPlayer then
        return instigator:GetPlayer()
    end
    return nil
end

function NPC.AttachDebugHP(npc_id, hp)
    local data = npc_id and NPC.List[npc_id]
    if not data or not data.character or not data.character:IsValid() then return end

    data.hp = hp or data.hp or 100
    data.max_hp = hp or data.max_hp or data.hp

    local npc = data.character
    if npc.SetCanDie then
        npc:SetCanDie((data.hp or 0) <= 0)
    end
    if npc.SetMaxHealth then
        npc:SetMaxHealth(data.max_hp)
    end
    if npc.SetHealth then
        if (data.hp or 0) > 0 then
            npc:SetHealth(data.max_hp)
        else
            npc:SetHealth(0)
        end
    end

    NPC.BroadcastUpdate(npc_id)

    if data.hp_subscribed or not npc.Subscribe then return end
    data.hp_subscribed = true

    local function OnDamaged(_, amount, _, instigator)
        if not data or not data.hp then return end
        local now = os.clock()
        if data.last_damage_t and (now - data.last_damage_t) < 0.05 then
            return
        end
        data.last_damage_t = now
        local dmg = tonumber(amount) or 0
        data.hp = math.max(0, data.hp - dmg)
        if npc.SetCanDie then
            npc:SetCanDie((data.hp or 0) <= 0)
        end
        if npc.SetMaxHealth then
            npc:SetMaxHealth(data.max_hp)
        end
        if npc.SetHealth then
            if (data.hp or 0) > 0 then
                npc:SetHealth(data.max_hp)
            else
                npc:SetHealth(0)
            end
        end
        NPC.BroadcastUpdate(npc_id)

        local msg = "[NPC] " .. tostring(data.name or npc_id)
            .. " HP: " .. tostring(math.floor(data.hp + 0.5))
            .. "/" .. tostring(math.floor((data.max_hp or data.hp) + 0.5))
            .. " (-" .. tostring(dmg) .. ")"
        LOG.Info(msg)

        local player = ResolvePlayerFromInstigator(instigator)
        if player and player.GetName then
            Events.CallRemote("FNV:HUD:Notify", player, { text = msg, ms = 1500 })
        end
    end

    npc:Subscribe("TakeDamage", OnDamaged)
    npc:Subscribe("Damage", OnDamaged)
end

function NPC.GetAllForClient()
    local out = {}
    for id, data in pairs(NPC.List) do
        if data.character and data.character:IsValid() then
            local payload = BuildNPCPayload(id, data, true)
            out[#out + 1] = payload
        end
    end
    return out
end

-- Client demande la liste (au load / reload / spawn)
Events.SubscribeRemote("FNV:NPC:RequestList", function(player)
    local list = NPC.GetAllForClient()
    Events.CallRemote("FNV:NPC:List", player, { npcs = list })
end)


-- Client demande d'afficher/cacher le prompt (basé caméra)
Events.SubscribeRemote("FNV:NPC:Prompt", function(player, payload)
    LOG.Info("[NPC] Prompt from " .. player:GetName() ..
        " show=" .. tostring(payload and payload.show) ..
        " id=" .. tostring(payload and payload.npc_id))

    local show = payload and payload.show
    local npc_id = payload and payload.npc_id

    if not show then
        return Events.CallRemote("FNV:Interact:Prompt", player, { show = false })
    end

    local data = npc_id and NPC.List[npc_id]
    if not data or not data.character or not data.character:IsValid() then
        return Events.CallRemote("FNV:Interact:Prompt", player, { show = false })
    end

    -- Optionnel: sécurité "pas trop loin" même pour afficher le prompt
    local pchar = player:GetControlledCharacter()
    if pchar then
        local ppos = pchar:GetLocation()
        local npos = data.character:GetLocation()
        if DistSq(ppos, npos) > (INTERACT_RANGE * INTERACT_RANGE) then
            return Events.CallRemote("FNV:Interact:Prompt", player, { show = false })
        end
    end

    Events.CallRemote("FNV:Interact:Prompt", player, {
        show = true,
        key = "E",
        action = "INTERAGIR",
        name = data.name or npc_id
    })
end)

-- Interaction (E)
Events.SubscribeRemote("FNV:NPC:Interact", function(player, payload)
    local npc_id = payload and payload.npc_id
    if not npc_id then return end

    LOG.Info("[NPC] Interact npc_id=" .. tostring(npc_id))

    local data = NPC.List[npc_id]
    if not data or not data.character or not data.character:IsValid() then return end

    local pchar = player:GetControlledCharacter()
    if not pchar then return end

    local ppos = pchar:GetLocation()
    local npos = data.character:GetLocation()

    if DistSq(ppos, npos) > (INTERACT_RANGE * INTERACT_RANGE) then
        Notify(player, "Trop loin.", 1500)
        return
    end

    Events.CallRemote("FNV:HUD:Notify", player, { text = "Vous parlez avec " .. data.name, ms = 2500 })
    if DIALOG and DIALOG.Start then
        DIALOG.Start(player, npc_id)
        LOG.Info("[DIALOG] Start npc_id=" .. tostring(npc_id))
    end
end)
