PAWN_TEST = PAWN_TEST or {}
PAWN_TEST.TIMER = PAWN_TEST.TIMER or nil
PAWN_TEST.ENTITY = PAWN_TEST.ENTITY or nil
PAWN_TEST.KIND = PAWN_TEST.KIND or nil
PAWN_TEST.DEBUG_TIMER = PAWN_TEST.DEBUG_TIMER or nil

local USE_MANUAL_FALLBACK = true

local function Log(msg)
    if LOG and LOG.Info then
        LOG.Info("[PAWN_TEST] " .. msg)
    end
end

local function Warn(msg)
    if LOG and LOG.Warn then
        LOG.Warn("[PAWN_TEST] " .. msg)
    end
end

local function RandomPoint(center, min_radius, max_radius)
    local angle = math.random() * math.pi * 2
    local dist = min_radius + (math.random() * (max_radius - min_radius))
    return center + Vector(math.cos(angle) * dist, math.sin(angle) * dist, 0)
end

function PAWN_TEST.Stop()
    if PAWN_TEST.TIMER then
        Timer.ClearInterval(PAWN_TEST.TIMER)
        PAWN_TEST.TIMER = nil
    end
    if PAWN_TEST.DEBUG_TIMER then
        Timer.ClearInterval(PAWN_TEST.DEBUG_TIMER)
        PAWN_TEST.DEBUG_TIMER = nil
    end
    if PAWN_TEST.ENTITY and PAWN_TEST.ENTITY.IsValid and PAWN_TEST.ENTITY:IsValid() then
        PAWN_TEST.ENTITY:Destroy()
    end
    PAWN_TEST.ENTITY = nil
    PAWN_TEST.KIND = nil
end

function PAWN_TEST.Start(location)
    PAWN_TEST.Stop()

    local rot = Rotator(0, 0, 0)
    local ent = nil
    local kind = "CharacterSimple"

    if CharacterSimple then
        ent = CharacterSimple(
            location,
            rot,
            "nanos-world::SK_StackOBot",
            "nanos-world::ABP_StackOBot"
        )
        if ent and ent.SetSpeedSettings then
            ent:SetSpeedSettings(275, 150)
        end
    else
        kind = "CharacterFallback"
        ent = Character(location, rot, "nanos-world::SK_Mannequin")
    end

    if not ent or not ent.IsValid or not ent:IsValid() then
        return Warn("Failed to spawn " .. kind)
    end

    PAWN_TEST.ENTITY = ent
    PAWN_TEST.KIND = kind

    math.randomseed(os.time())
    local center = location
    local acceptance_radius = 120
    local last_move_t = os.clock()
    local last_target = nil
    local move_delay_ms = 0

    local function GoNext()
        if not ent or not ent.IsValid or not ent:IsValid() then
            PAWN_TEST.Stop()
            return
        end
        local target = RandomPoint(center, 2000, 3500)
        last_target = target
        last_move_t = os.clock()
        if ent.LookAt then
            ent:LookAt(target)
        end
        local min_speed = 120
        local max_speed = 260
        if ent.SetSpeedSettings then
            local walk = min_speed + math.random() * (max_speed - min_speed)
            ent:SetSpeedSettings(walk, walk * 0.6)
        end
        if ent.MoveTo then
            ent:MoveTo(target, acceptance_radius)
            Log("MoveTo -> " .. tostring(target))
        elseif ent.SetLocation and USE_MANUAL_FALLBACK then
            ent:SetLocation(target)
        end
    end

    local function ScheduleNext()
        move_delay_ms = 1000 + math.random(0, 4000)
        Timer.SetTimeout(function()
            GoNext()
        end, move_delay_ms)
    end

    ScheduleNext()
    if ent.Subscribe then
        ent:Subscribe("MoveComplete", function(_, succeeded)
            if not ent or not ent.IsValid or not ent:IsValid() then
                PAWN_TEST.Stop()
                return
            end
            Log("MoveComplete succeeded=" .. tostring(succeeded))
            if not succeeded and ent.StopMovement then
                ent:StopMovement()
            end
            ScheduleNext()
        end)
    end
    if USE_MANUAL_FALLBACK and ent.SetLocation then
        PAWN_TEST.DEBUG_TIMER = Timer.SetInterval(function()
            if not ent or not ent.IsValid or not ent:IsValid() then
                PAWN_TEST.Stop()
                return
            end
            if not last_target then return end
            local pos = ent.GetLocation and ent:GetLocation()
            if not pos then return end
            local dx = last_target.X - pos.X
            local dy = last_target.Y - pos.Y
            local dz = last_target.Z - pos.Z
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
            if dist <= acceptance_radius then
                return
            end
            local now = os.clock()
            if (now - last_move_t) > 2.0 then
                -- No MoveComplete; use manual nudge to show movement without navmesh.
                local step = 60
                local len = math.sqrt(dx * dx + dy * dy + dz * dz)
                if len > 0 then
                    ent:SetLocation(Vector(pos.X + (dx / len) * step, pos.Y + (dy / len) * step, pos.Z + (dz / len) * step))
                end
            end
        end, 250)
    end
    Log(kind .. " test started")
end
