SPECIAL = {}

local function Clamp(value)
    value = tonumber(value) or 5
    if value < 1 then return 1 end
    if value > 10 then return 10 end
    return value
end

local function BuildSpecial(state)
    local sp = state.special or {}
    return {
        str = Clamp(sp.str or state.strength),
        per = Clamp(sp.per or state.perception),
        endu = Clamp(sp.endu or sp.endurance or state.endurance),
        cha = Clamp(sp.cha or state.charisma),
        intel = Clamp(sp.intel or sp.intelligence),
        agi = Clamp(sp.agi or state.agility),
        lck = Clamp(sp.lck or state.luck)
    }
end

function SPECIAL.CalcDerived(state)
    local sp = BuildSpecial(state)

    local derived = {
        carry_weight_max = (sp.str * 10) + 150,
        melee_damage = sp.str * 0.5,
        crit_chance = sp.lck,
        poison_resist = (sp.endu * 5) - 5,
        rad_resist = (sp.endu * 2) - 2,
        healing_rate = (sp.endu >= 9 and 10) or (sp.endu >= 6 and 5) or 0,
        skill_rate = (sp.intel * 0.5) + 10,
        reload_speed = 10 / (sp.agi + 5),
        implant_limit = sp.endu,
        repair_skill = 2 + (2 * sp.intel) + math.ceil(sp.lck / 2)
    }

    return sp, derived
end

function SPECIAL.Init(state)
    if not state then return end
    local sp, derived = SPECIAL.CalcDerived(state)
    state.special = sp

    -- Keep legacy fields in sync for AP/HP calculators.
    state.strength = sp.str
    state.perception = sp.per
    state.endurance = sp.endu
    state.charisma = sp.cha
    state.intelligence = sp.intel
    state.agility = sp.agi
    state.luck = sp.lck

    state.carry_weight_max = derived.carry_weight_max
    state.melee_damage = derived.melee_damage
    state.crit_chance = derived.crit_chance
    state.poison_resist = derived.poison_resist
    state.rad_resist = derived.rad_resist
    state.healing_rate = derived.healing_rate
    state.skill_rate = derived.skill_rate
    state.reload_speed = derived.reload_speed
    state.implant_limit = derived.implant_limit
    state.repair_skill = derived.repair_skill
    state.repair_cap = math.min(100, derived.repair_skill or 0)
end
