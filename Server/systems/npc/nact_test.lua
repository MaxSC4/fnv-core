NACT_TEST = NACT_TEST or {}

local TERRITORY_ID = "fnv_test"
local NPC_ID = "nact_raider"

local TERRITORY_CENTER = Vector(1500, 850, 300)
local NPC_SPAWN = Vector(1650, 850, 300)
local NPC_ROT = Rotator(0, 180, 0)

local function IsValidEntity(ent)
    return ent and ent.IsValid and ent:IsValid()
end

local function BuildWeaponFromDef(def)
    if not def or not def.weapon or not def.weapon.mesh then return nil end
    local wdef = def.weapon
    local w = Weapon(Vector(), Rotator(), wdef.mesh)
    if not w then return nil end

    if w.SetAmmoSettings then
        local ammo = wdef.ammo or 1
        local reserve = wdef.reserve or 0
        if wdef.infinite_ammo then
            ammo = 9999
            reserve = 9999
        end
        w:SetAmmoSettings(ammo, reserve)
        w:SetAmmoSettings(9999, 9999)
    end
    if w.SetAutoReload then
        w:SetAutoReload(true)
    end
    if wdef.damage and w.SetDamage then w:SetDamage(wdef.damage) end
    if wdef.spread and w.SetSpread then w:SetSpread(wdef.spread) end
    if wdef.recoil and w.SetRecoil then w:SetRecoil(wdef.recoil) end
    if wdef.cadence and w.SetCadence then w:SetCadence(wdef.cadence) end
    if wdef.handling_mode and w.SetHandlingMode then
        w:SetHandlingMode(wdef.handling_mode)
    end
    if wdef.particles then
        if wdef.particles.bullet_trail and w.SetParticlesBulletTrail then
            w:SetParticlesBulletTrail(wdef.particles.bullet_trail)
        end
        if wdef.particles.barrel and w.SetParticlesBarrel then
            w:SetParticlesBarrel(wdef.particles.barrel)
        end
        if wdef.particles.shells and w.SetParticlesShells then
            w:SetParticlesShells(wdef.particles.shells)
        end
    end

    return w
end

local function EnsureTerritory()
    if NACT_TEST.territory then
        return NACT_TEST.territory
    end
    if not NACT or not NACT.RegisterTerritory then
        if LOG and LOG.Warn then LOG.Warn("[NACT] RegisterTerritory unavailable") end
        return nil
    end
    NACT_TEST.territory = NACT.RegisterTerritory(TERRITORY_ID, {
        zoneBounds = {
            pos = TERRITORY_CENTER,
            radius = 2200
        },
        team = 1,
        enemyFilter = function(entity)
            return entity and entity.GetPlayer and entity:GetPlayer() ~= nil
        end
    })
    return NACT_TEST.territory
end

function NACT_TEST.Start()
    if not NACT or not NACT.RegisterNpc then
        if LOG and LOG.Warn then LOG.Warn("[NACT] RegisterNpc unavailable") end
        return
    end
    if IsValidEntity(NACT_TEST.npc) then
        return
    end

    local territory = EnsureTerritory()
    if not territory then return end

    local npc = Character(NPC_SPAWN, NPC_ROT, "nanos-world::SK_Mannequin")
    if npc.SetTeam then
        npc:SetTeam(1)
    end

    local def = ITEMS and ITEMS.Get and ITEMS.Get("varmint_rifle")
    if def then
        local weapon = BuildWeaponFromDef(def)
        if weapon and npc.PickUp then
            npc:PickUp(weapon)
        end
    end

    local config = NACT.Defaults and NACT.Defaults.Millitary and NACT.Defaults.Millitary.Soldier or {}
    local behaviors = {}
    for _, entry in ipairs(config.behaviors or {}) do
        if entry.class ~= NACT_Cover then
            behaviors[#behaviors + 1] = entry
        end
    end
    local has_seek = false
    local has_engage = false
    for _, entry in ipairs(behaviors) do
        if entry.class == NACT_Seek then
            has_seek = true
        end
        if entry.class == NACT_Engage then
            has_engage = true
            entry.config = entry.config or {}
            entry.config.desiredDistance = 1400
            entry.config.minDistance = 800
        end
        if entry.class == NACT_Combat then
            entry.config = entry.config or {}
            entry.config.coverBehavior = NACT_Seek
            entry.config.seekBehavior = NACT_Seek
            entry.config.attackBehavior = NACT_Engage
        end
    end
    if not has_seek then
        behaviors[#behaviors + 1] = { class = NACT_Seek }
    end
    if not has_engage then
        behaviors[#behaviors + 1] = { class = NACT_Engage }
    end
    local npc_config = {
        behaviors = behaviors,
        autoVision = true,
        visionAngle = -1
    }
    NACT.RegisterNpc(npc, TERRITORY_ID, npc_config)

    NACT_TEST.npc = npc

    if NPC and NPC.Register then
        NPC.Register(NPC_ID, npc, "Raider")
        local data = NPC.List and NPC.List[NPC_ID]
        if data then
            data.hp = 250
            data.max_hp = 250
            data.dt = 8
        end
        if NPC.SetHostile then
            NPC.SetHostile(NPC_ID, true)
        end
        if NPC.AttachDebugHP then
            NPC.AttachDebugHP(NPC_ID, 250, data and data.dt or 0)
        end
    end
end

function NACT_TEST.Stop()
    local npc = NACT_TEST.npc
    if npc and npc.IsValid and npc:IsValid() then
        if NACT and NACT.CharacterCleanup then
            NACT.CharacterCleanup(npc)
        end
        npc:Destroy()
    end
    NACT_TEST.npc = nil
    if NPC and NPC.Unregister then
        NPC.Unregister(NPC_ID)
    end
end
