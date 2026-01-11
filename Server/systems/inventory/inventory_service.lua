INV_SERVICE = INV_SERVICE or {}
INV_SERVICE.SESSIONS = INV_SERVICE.SESSIONS or {}
INV_SERVICE.WEAPONS = INV_SERVICE.WEAPONS or {}
INV_SERVICE.WEAPON_HOLSTER = INV_SERVICE.WEAPON_HOLSTER or {}
INV_SERVICE.AMMO_TIMERS = INV_SERVICE.AMMO_TIMERS or {}
INV_SERVICE.AMMO_STATE = INV_SERVICE.AMMO_STATE or {}

local function ClampCondition(condition)
    condition = tonumber(condition)
    if condition == nil then return 100 end
    if condition < 0 then return 0 end
    if condition > 100 then return 100 end
    return condition
end

local function DamageScaleFromCondition(condition)
    local pct = ClampCondition(condition) / 100
    local scaled = 0.5 + math.min((0.5 * pct) / 0.75, 0.5)
    return math.max(0.5, math.min(1.0, scaled))
end

local function ApplyWeaponDamageFromCondition(weapon, def, condition)
    if not weapon or not def or not def.weapon then return end
    local base = def.weapon.damage
    if not base or not weapon.SetDamage then return end
    local scale = DamageScaleFromCondition(condition)
    weapon:SetDamage(base * scale)
end

local RefreshInventory

local function SetMode(player, mode)
    Events.CallRemote("FNV:UI:SetMode", player, { mode = mode })
end

local function FreezePlayerForInventory(player, freeze)
    local char = player and player.GetControlledCharacter and player:GetControlledCharacter()
    if not char or not char.IsValid or not char:IsValid() then return end
    if char.SetInputEnabled then
        char:SetInputEnabled(not freeze)
    end
end

local function SendOpen(player, payload)
    Events.CallRemote("FNV:Inv:Open", player, payload)
end

local function SendClose(player)
    Events.CallRemote("FNV:Inv:Close", player, { open = false })
end

local function SaveInventoryState(player, state)
    local player_id = PLAYERS and PLAYERS.GetID and PLAYERS.GetID(player)
    if not player_id or not state then return end
    if INV_STORE and INV_STORE.Save then
        INV_STORE.Save(player_id, state.inventory)
    end
end

local function GetCharacter(player)
    if not player or not player.GetControlledCharacter then return nil end
    local char = player:GetControlledCharacter()
    if not char or not char.IsValid or not char:IsValid() then return nil end
    return char
end

local function StopAmmoTracking(player, state, clear)
    local timer_id = INV_SERVICE.AMMO_TIMERS[player]
    if timer_id then
        Timer.ClearInterval(timer_id)
        INV_SERVICE.AMMO_TIMERS[player] = nil
    end
    INV_SERVICE.AMMO_STATE[player] = nil
    if clear and state then
        state.ammo = { now = 0, reserve = 0 }
        if HUD_SYNC and HUD_SYNC.Send then
            HUD_SYNC.Send(player, state)
        end
    end
end

local function DestroyWeaponFor(player)
    local w = INV_SERVICE.WEAPONS[player]
    if w and w.IsValid and w:IsValid() then
        w:Destroy()
    end
    INV_SERVICE.WEAPONS[player] = nil
end

local function SendHolsterState(player, holstered)
    Events.CallRemote("FNV:Weapon:HolsterState", player, { holstered = holstered == true })
end

local function ApplyWeapon(player, def, state, inst)
    local char = GetCharacter(player)
    if not char or not def or not def.weapon then return end

    DestroyWeaponFor(player)

    local wdef = def.weapon
    if not wdef.mesh then return end

    local w = Weapon(char:GetLocation() + Vector(0, 0, 50), Rotator(0, 0, 0), wdef.mesh)

    if w.SetAmmoSettings then
        local ammo = wdef.ammo
        local reserve = wdef.reserve
        if wdef.infinite_ammo then
            ammo = 9999
            reserve = 9999
        end
        if wdef.ammo_type and not wdef.infinite_ammo then
            reserve = 0
        end
        if ammo and reserve then
            w:SetAmmoSettings(ammo, reserve)
        end
    end
    if wdef.damage and w.SetDamage then
        ApplyWeaponDamageFromCondition(w, def, inst and inst.condition or def.cnd or 100)
    end
    if wdef.spread and w.SetSpread then w:SetSpread(wdef.spread) end
    if wdef.recoil and w.SetRecoil then w:SetRecoil(wdef.recoil) end
    if wdef.cadence and w.SetCadence then w:SetCadence(wdef.cadence) end
    if wdef.handling_mode and w.SetHandlingMode then
        w:SetHandlingMode(wdef.handling_mode)
    end
    if wdef.particles then
        local p = wdef.particles
        if p.bullet_trail and w.SetParticlesBulletTrail then
            w:SetParticlesBulletTrail(p.bullet_trail)
        end
        if p.barrel and w.SetParticlesBarrel then
            w:SetParticlesBarrel(p.barrel)
        end
        if p.shells and w.SetParticlesShells then
            w:SetParticlesShells(p.shells)
        end
    end

    if char.PickUp then
        char:PickUp(w)
    end

    INV_SERVICE.WEAPONS[player] = w

    if state then
        local wdef = def.weapon
        local last_now = nil
        local last_reserve = nil
        StopAmmoTracking(player, state, false)
        local ammo_type = wdef.ammo_type
        local ammo_state = {
            clip_now = wdef.ammo or 0,
            instance_id = inst and inst.id or nil
        }
        if wdef.infinite_ammo then
            ammo_state.clip_now = 9999
        end
        INV_SERVICE.AMMO_STATE[player] = ammo_state

        local function ConsumeAmmo(amount)
            if wdef.infinite_ammo then return end
            amount = tonumber(amount) or 1
            if amount <= 0 then return end
            local clip = ammo_state.clip_now or 0
            if clip <= 0 then return end
            local new_clip = clip - amount
            if new_clip < 0 then new_clip = 0 end
            ammo_state.clip_now = new_clip
            ammo_state.last_event_clip = new_clip
            if ammo_state.instance_id and state.inventory and state.inventory.instances then
                local w_inst = state.inventory.instances[ammo_state.instance_id]
                if w_inst then
                    w_inst.condition = ClampCondition((w_inst.condition or def.cnd or 100) - 0.2)
                    ApplyWeaponDamageFromCondition(w, def, w_inst.condition)
                    if LOG and LOG.Info then
                        LOG.Info(string.format("[CND] weapon=%s instance=%s cnd=%.2f",
                            tostring(def and def.name or def and def.id or "weapon"),
                            tostring(ammo_state.instance_id),
                            tonumber(w_inst.condition) or 0))
                    end
                end
            end
            if w.SetAmmoSettings then
                w:SetAmmoSettings(new_clip, 0)
            end
            state.ammo = {
                now = new_clip,
                reserve = state.ammo and state.ammo.reserve or 0
            }
            if HUD_SYNC and HUD_SYNC.Send then
                HUD_SYNC.Send(player, state)
            end
        end

        local function ReadAmmo()
            if not w or not w.IsValid or not w:IsValid() then
                StopAmmoTracking(player, state, true)
                return
            end

            local now = nil
            if w.GetAmmo then now = w:GetAmmo() end
            if now == nil and w.GetAmmoInClip then now = w:GetAmmoInClip() end
            if now == nil then now = ammo_state.clip_now or wdef.ammo or 0 end

            local reserve = nil
            if ammo_type and INV and INV.Count and state.inventory then
                reserve = INV.Count(state.inventory, ammo_type)
            else
                if w.GetAmmoTotal then reserve = w:GetAmmoTotal() end
                if reserve == nil and w.GetAmmoReserve then reserve = w:GetAmmoReserve() end
                if reserve == nil then reserve = wdef.reserve or 0 end
            end
            if wdef.infinite_ammo then
                reserve = 9999
            end

            if last_now ~= nil and now ~= nil and now < last_now and now ~= ammo_state.last_event_clip then
                local delta = last_now - now
                for _ = 1, delta do
                    ConsumeAmmo(1)
                end
                ammo_state.last_event_clip = now
            end

            if now ~= last_now or reserve ~= last_reserve then
                state.ammo = { now = now, reserve = reserve }
                last_now = now
                last_reserve = reserve
                if HUD_SYNC and HUD_SYNC.Send then
                    HUD_SYNC.Send(player, state)
                end
            end
        end

        if w.Subscribe then
            w:Subscribe("Fire", function()
                ConsumeAmmo(1)
            end)
            w:Subscribe("OnFire", function()
                ConsumeAmmo(1)
            end)
        end

        ReadAmmo()
        INV_SERVICE.AMMO_TIMERS[player] = Timer.SetInterval(ReadAmmo, 150)
    end
end

local function ApplyHolsterVisual(player, def)
    local char = GetCharacter(player)
    if not char or not def or not def.weapon or not def.weapon.holster then return end
    local h = def.weapon.holster
    local attached = nil
    if h.kind == "skeletal" and char.AddSkeletalMeshAttached and h.socket and h.mesh then
        attached = char:AddSkeletalMeshAttached(h.socket, h.mesh)
    elseif h.kind == "static" and char.AddStaticMeshAttached and h.socket and h.mesh then
        attached = char:AddStaticMeshAttached(h.socket, h.mesh, h.bone or h.socket)
    end
    if attached then
        if h.location and attached.SetRelativeLocation then
            attached:SetRelativeLocation(h.location)
        elseif h.location and attached.SetLocation then
            attached:SetLocation(h.location)
        end
        if h.rotation and attached.SetRelativeRotation then
            attached:SetRelativeRotation(h.rotation)
        elseif h.rotation and attached.SetRotation then
            attached:SetRotation(h.rotation)
        end
        INV_SERVICE.WEAPON_HOLSTER[player] = attached
    end
end

local function ClearHolsterVisual(player, def)
    local char = GetCharacter(player)
    if not char or not def or not def.weapon or not def.weapon.holster then return end
    local h = def.weapon.holster
    if h.kind == "skeletal" and char.RemoveSkeletalMeshAttached and h.socket then
        char:RemoveSkeletalMeshAttached(h.socket)
    elseif h.kind == "static" and char.RemoveStaticMeshAttached and h.socket then
        char:RemoveStaticMeshAttached(h.socket)
    end
    INV_SERVICE.WEAPON_HOLSTER[player] = nil
end

local function GetEquippedWeaponDef(state)
    if not state or not state.equipped or not state.inventory or not state.inventory.instances then
        return nil, nil
    end
    local weapon_id = state.equipped.weapon_instance_id
    if not weapon_id then return nil, nil end
    local inst = state.inventory.instances[weapon_id]
    if not inst then return nil, nil end
    local def = ITEMS and ITEMS.Get and ITEMS.Get(inst.base_id)
    if not def or def.category ~= "weapons" then return nil, nil end
    return def, inst
end

local function SetWeaponHolstered(player, state, holstered)
    local def = GetEquippedWeaponDef(state)
    if not def then return end

    state.equipped = state.equipped or {}
    state.equipped.weapon_holstered = holstered == true
    if holstered then
        DestroyWeaponFor(player)
        StopAmmoTracking(player, state, true)
        ApplyHolsterVisual(player, def)
    else
        ClearHolsterVisual(player, def)
        ApplyWeapon(player, def, state, inst)
    end

    SendHolsterState(player, holstered)
end

local function ReloadWeapon(player, state)
    local def, inst = GetEquippedWeaponDef(state)
    local w = INV_SERVICE.WEAPONS[player]
    if not def or not def.weapon or not w or not w.IsValid or not w:IsValid() then return end
    if state.equipped and state.equipped.weapon_holstered then return end

    local wdef = def.weapon
    if wdef.infinite_ammo then
        if w.SetAmmoSettings and wdef.ammo then
            w:SetAmmoSettings(wdef.ammo, 9999)
        end
        state.ammo = { now = wdef.ammo or 0, reserve = 9999 }
        if HUD_SYNC and HUD_SYNC.Send then HUD_SYNC.Send(player, state) end
        return
    end

    local ammo_type = wdef.ammo_type
    if not ammo_type or not state.inventory then return end
    local clip_size = tonumber(wdef.ammo) or 0
    if clip_size <= 0 then return end

    local current = nil
    if w.GetAmmo then current = w:GetAmmo() end
    if current == nil and w.GetAmmoInClip then current = w:GetAmmoInClip() end
    if current == nil then
        current = INV_SERVICE.AMMO_STATE[player] and INV_SERVICE.AMMO_STATE[player].clip_now or 0
    end
    current = tonumber(current) or 0

    local need = clip_size - current
    if need <= 0 then return end

    local available = INV and INV.Count and INV.Count(state.inventory, ammo_type) or 0
    if available <= 0 then
        if HUD_NOTIFY and HUD_NOTIFY.Send then
            HUD_NOTIFY.Send(player, "Plus de munitions", 1500)
        end
        return
    end

    local to_load = math.min(need, available)
    local ok = INV and INV.Remove and INV.Remove(state.inventory, ammo_type, to_load)
    if not ok then return end

    local new_clip = current + to_load
    local reserve = INV and INV.Count and INV.Count(state.inventory, ammo_type) or 0
    if w.SetAmmoSettings then
        w:SetAmmoSettings(new_clip, 0)
    end
    if INV_SERVICE.AMMO_STATE[player] then
        INV_SERVICE.AMMO_STATE[player].clip_now = new_clip
    end

    state.ammo = { now = new_clip, reserve = reserve }
    if HUD_SYNC and HUD_SYNC.Send then HUD_SYNC.Send(player, state) end
    SaveInventoryState(player, state)
    RefreshInventory(player, state)
end

local function ClearVisual(player, def)
    local char = GetCharacter(player)
    if not char or not def or not def.visual then return end
    local v = def.visual
    if v.kind == "skeletal" and char.RemoveSkeletalMeshAttached and v.socket then
        char:RemoveSkeletalMeshAttached(v.socket)
    elseif v.kind == "static" and char.RemoveStaticMeshAttached and v.socket then
        char:RemoveStaticMeshAttached(v.socket)
    end
end

local function ApplyVisual(player, def)
    local char = GetCharacter(player)
    if not char or not def or not def.visual then return end
    local v = def.visual
    if v.kind == "skeletal" and char.AddSkeletalMeshAttached and v.socket and v.mesh then
        char:AddSkeletalMeshAttached(v.socket, v.mesh)
    elseif v.kind == "static" and char.AddStaticMeshAttached and v.socket and v.mesh then
        char:AddStaticMeshAttached(v.socket, v.mesh, v.bone or v.socket)
    end
end

local function SetEquippedInstance(state, instance_id, slot)
    state.equipped = state.equipped or {}
    if slot == "weapon" then
        state.equipped.weapon_instance_id = instance_id
    elseif slot == "head" then
        state.equipped.armor_head_instance_id = instance_id
    else
        state.equipped.armor_body_instance_id = instance_id
    end
end

local function ApplyEquippedVisuals(player, state)
    if not state or not state.inventory then return end
    local inv = INV and INV.Normalize and INV.Normalize(state.inventory) or state.inventory
    if not inv or not inv.instances then return end

    state.equipped = state.equipped or {}
    for _, inst in pairs(inv.instances) do
        if inst and inst.equipped then
            local def = ITEMS and ITEMS.Get and ITEMS.Get(inst.base_id)
            if def and def.category == "apparel" then
                local slot = def.slot or "body"
                SetEquippedInstance(state, inst.id, slot)
                ApplyVisual(player, def)
            elseif def and def.category == "weapons" then
                SetEquippedInstance(state, inst.id, "weapon")
                if state.equipped and state.equipped.weapon_holstered then
                    ApplyHolsterVisual(player, def)
                else
                    ApplyWeapon(player, def, state, inst)
                end
                SendHolsterState(player, state.equipped and state.equipped.weapon_holstered)
            end
        end
    end
end

RefreshInventory = function(player, state)
    if not INV_SERVICE.SESSIONS[player] then return end
    local payload = INV.BuildPayload(state)
    if payload then
        SendOpen(player, payload)
    end
end

local function ClearEquippedInstance(state, instance_id)
    if not state or not state.equipped or not instance_id then return end
    if state.equipped.weapon_instance_id == instance_id then
        state.equipped.weapon_instance_id = nil
    end
    if state.equipped.armor_body_instance_id == instance_id then
        state.equipped.armor_body_instance_id = nil
    end
    if state.equipped.armor_head_instance_id == instance_id then
        state.equipped.armor_head_instance_id = nil
    end
end

function INV_SERVICE.Open(player)
    if INV_SERVICE.SESSIONS[player] then return end
    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state then return end

    local payload = INV.BuildPayload(state)
    if not payload then return end

    INV_SERVICE.SESSIONS[player] = true
    SendOpen(player, payload)
    FreezePlayerForInventory(player, true)
    SetMode(player, "inventory")
end

function INV_SERVICE.Close(player)
    if not INV_SERVICE.SESSIONS[player] then return end
    INV_SERVICE.SESSIONS[player] = nil
    SendClose(player)
    FreezePlayerForInventory(player, false)
    SetMode(player, "gameplay")
end

Events.SubscribeRemote("FNV:Inv:OpenRequest", function(player, payload)
    INV_SERVICE.Open(player)
end)

Events.SubscribeRemote("FNV:Inv:CloseRequest", function(player, payload)
    INV_SERVICE.Close(player)
end)

Events.SubscribeRemote("FNV:Inv:Action", function(player, payload)
    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state or not state.inventory then return end

    local action = payload and payload.action
    local item_id = payload and payload.item_id
    local instance_id = payload and payload.instance_id
    if not action or not item_id then return end

    local def = ITEMS and ITEMS.Get and ITEMS.Get(item_id)
    if not def then return end

    if action == "use" then
        local ok, reason = ITEM_USE.Use(state, item_id, instance_id, player)
        if not ok and HUD_NOTIFY and HUD_NOTIFY.Send then
            HUD_NOTIFY.Send(player, "Use failed: " .. tostring(reason), 2000)
        end
        if HUD_SYNC and HUD_SYNC.MarkDirty then
            HUD_SYNC.MarkDirty(state)
            if HUD_SYNC.Flush then
                HUD_SYNC.Flush(player, state)
            else
                HUD_SYNC.Send(player, state)
            end
        end
        SaveInventoryState(player, state)
        RefreshInventory(player, state)
        return
    end

    if action == "equip" then
        if not instance_id or not INV.HasInstance(state.inventory, instance_id, item_id) then
            if HUD_NOTIFY and HUD_NOTIFY.Send then
                HUD_NOTIFY.Send(player, "Cannot equip: invalid item", 2000)
            end
            return
        end

        local slot = "weapon"
        if def.category == "apparel" then
            slot = def.slot or "body"
        end

        local inst = state.inventory.instances and state.inventory.instances[instance_id]
        if inst and inst.equipped then
            inst.equipped = false
            ClearEquippedInstance(state, instance_id)
            if def.category == "apparel" then
                ClearVisual(player, def)
            elseif def.category == "weapons" then
                DestroyWeaponFor(player)
                ClearHolsterVisual(player, def)
                state.equipped.weapon_holstered = false
                StopAmmoTracking(player, state, true)
                SendHolsterState(player, false)
            end
        else
            -- clear previous for slot
            if slot == "weapon" and state.equipped and state.equipped.weapon_instance_id then
                local old = state.equipped.weapon_instance_id
                if state.inventory.instances and state.inventory.instances[old] then
                    state.inventory.instances[old].equipped = false
                    local old_def = ITEMS.Get(state.inventory.instances[old].base_id)
                    if old_def and old_def.category == "weapons" then
                        DestroyWeaponFor(player)
                        ClearHolsterVisual(player, old_def)
                        StopAmmoTracking(player, state, true)
                    end
                end
            elseif slot == "head" and state.equipped and state.equipped.armor_head_instance_id then
                local old = state.equipped.armor_head_instance_id
                if state.inventory.instances and state.inventory.instances[old] then
                    state.inventory.instances[old].equipped = false
                    local old_def = ITEMS.Get(state.inventory.instances[old].base_id)
                    if old_def and old_def.category == "apparel" then
                        ClearVisual(player, old_def)
                    end
                end
            elseif slot == "body" and state.equipped and state.equipped.armor_body_instance_id then
                local old = state.equipped.armor_body_instance_id
                if state.inventory.instances and state.inventory.instances[old] then
                    state.inventory.instances[old].equipped = false
                    local old_def = ITEMS.Get(state.inventory.instances[old].base_id)
                    if old_def and old_def.category == "apparel" then
                        ClearVisual(player, old_def)
                    end
                end
            end

            if inst then
                inst.equipped = true
            end
            SetEquippedInstance(state, instance_id, slot)
            if def.category == "apparel" then
                ApplyVisual(player, def)
            elseif def.category == "weapons" then
                state.equipped.weapon_holstered = false
                ClearHolsterVisual(player, def)
                ApplyWeapon(player, def, state, inst)
                SendHolsterState(player, false)
            end
        end

        SaveInventoryState(player, state)
        RefreshInventory(player, state)
        return
    end

    if action == "drop" then
        local amount = payload and payload.amount or 1
        local ok = LOOT and LOOT.DropFromPlayer and LOOT.DropFromPlayer(player, state, item_id, amount, instance_id)
        if not ok then
            if HUD_NOTIFY and HUD_NOTIFY.Send then
                HUD_NOTIFY.Send(player, "Drop failed", 2000)
            end
            return
        end
        if instance_id then
            ClearEquippedInstance(state, instance_id)
            if def.category == "apparel" then
                ClearVisual(player, def)
            elseif def.category == "weapons" then
                DestroyWeaponFor(player)
                ClearHolsterVisual(player, def)
                state.equipped.weapon_holstered = false
                StopAmmoTracking(player, state, true)
                SendHolsterState(player, false)
            end
        end
        SaveInventoryState(player, state)
        RefreshInventory(player, state)
        return
    end

    if action == "inspect" then
        if HUD_NOTIFY and HUD_NOTIFY.Send then
            HUD_NOTIFY.Send(player, tostring(def.desc or def.info or def.name or item_id), 3000)
        end
        return
    end

    if action == "repair" or action == "mod" then
        if HUD_NOTIFY and HUD_NOTIFY.Send then
            HUD_NOTIFY.Send(player, "Action not implemented", 2000)
        end
        return
    end
end)

Events.SubscribeRemote("FNV:Weapon:ToggleHolster", function(player, payload)
    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state or not state.equipped or not state.equipped.weapon_instance_id then return end
    local holstered = state.equipped.weapon_holstered == true
    SetWeaponHolstered(player, state, not holstered)
end)

Events.SubscribeRemote("FNV:Weapon:SetHolstered", function(player, payload)
    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state or not state.equipped or not state.equipped.weapon_instance_id then return end
    local holstered = payload and payload.holstered == true
    SetWeaponHolstered(player, state, holstered)
end)

Events.SubscribeRemote("FNV:Weapon:ReloadRequest", function(player, payload)
    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state or not state.equipped or not state.equipped.weapon_instance_id then return end
    ReloadWeapon(player, state)
end)

Events.SubscribeRemote("FNV:Weapon:ForcePickup", function(player, weapon)
    local char = GetCharacter(player)
    if not char or not weapon or not weapon.IsValid or not weapon:IsValid() then return end
    if char.PickUp then
        char:PickUp(weapon)
    end
end)

Player.Subscribe("Destroy", function(player)
    INV_SERVICE.SESSIONS[player] = nil
    DestroyWeaponFor(player)
    StopAmmoTracking(player, nil, false)
    INV_SERVICE.WEAPON_HOLSTER[player] = nil
    FreezePlayerForInventory(player, false)
end)

function INV_SERVICE.ApplyEquipped(player)
    local state = PLAYERS and PLAYERS.GetState and PLAYERS.GetState(player)
    if not state then return end
    ApplyEquippedVisuals(player, state)
end
