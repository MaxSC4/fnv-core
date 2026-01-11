INV = {}

local function IsTable(t) return type(t) == "table" end

function INV.New()
    return {
        _version = 2,
        stacks = {},
        instances = {},
        next_instance_id = 1
    }
end

function INV.Normalize(inv)
    if not IsTable(inv) then
        return INV.New()
    end

    if inv.stacks and inv.instances then
        inv._version = inv._version or 2
        inv.next_instance_id = inv.next_instance_id or 1

        local normalized_instances = {}
        local next_id = inv.next_instance_id
        for id, inst in pairs(inv.instances) do
            if type(inst) == "table" then
                local num_id = tonumber(id) or id
                inst.id = num_id
                normalized_instances[num_id] = inst
                if type(num_id) == "number" and num_id >= next_id then
                    next_id = num_id + 1
                end
            end
        end
        inv.instances = normalized_instances
        inv.next_instance_id = next_id
        return inv
    end

    local out = INV.New()
    for item_id, qty in pairs(inv) do
        if type(item_id) == "string" and type(qty) == "number" then
            out.stacks[item_id] = {
                stack_key = item_id,
                base_id = item_id,
                qty = qty
            }
        end
    end

    return out
end

local function GetDef(item_id)
    return ITEMS and ITEMS.Get and ITEMS.Get(item_id)
end

local function IsStackable(def)
    if def and def.stackable == false then return false end
    return def and def.max_stack and def.max_stack > 1
end

local function ClampCondition(condition)
    condition = tonumber(condition)
    if condition == nil then return nil end
    if condition < 0 then return 0 end
    if condition > 100 then return 100 end
    return condition
end

function INV.CalcValue(def, condition)
    local base = def and def.value
    if base == nil then return nil end
    local cnd = ClampCondition(condition)
    if cnd == nil then return base end
    local pct = math.max(0, math.min(1, cnd / 100))
    local scaled = base * (pct ^ 1.5)
    return math.max(1, math.floor(scaled + 0.5))
end

local function GetStackKey(def, item_id, instance_data)
    if not IsStackable(def) then return nil end
    local variant = instance_data and instance_data.variant or def and def.variant
    if variant then
        return item_id .. ":" .. tostring(variant)
    end
    return item_id
end

function INV.Add(inv, item_id, amount, instance_data)
    amount = tonumber(amount) or 1
    if amount <= 0 then return false, "invalid_amount" end

    inv = INV.Normalize(inv)

    local def = GetDef(item_id)
    if not def then return false, "unknown_item" end

    if IsStackable(def) then
        local stack_key = GetStackKey(def, item_id, instance_data)
        local stack = inv.stacks[stack_key]
        if not stack then
            stack = { stack_key = stack_key, base_id = item_id, qty = 0 }
            inv.stacks[stack_key] = stack
        end

        local max_stack = def.max_stack or 999999
        if stack.qty + amount > max_stack then
            return false, "stack_limit"
        end

        stack.qty = stack.qty + amount
        return true
    end

    for i = 1, amount do
        local id = inv.next_instance_id
        inv.next_instance_id = id + 1

        inv.instances[id] = {
            id = id,
            base_id = item_id,
            condition = (instance_data and instance_data.condition) or def.cnd or 100,
            mods = (instance_data and instance_data.mods) or {},
            custom_name = instance_data and instance_data.custom_name or nil,
            equipped = instance_data and instance_data.equipped or false,
            extra = instance_data and instance_data.extra or nil
        }
    end

    return true
end

local function RemoveInstance(inv, instance_id)
    if inv.instances[instance_id] then
        inv.instances[instance_id] = nil
        return true
    end
    return false
end

function INV.Remove(inv, item_id, amount, instance_id)
    amount = tonumber(amount) or 1
    if amount <= 0 then return false, "invalid_amount" end

    inv = INV.Normalize(inv)
    local def = GetDef(item_id)
    if not def then return false, "unknown_item" end

    if instance_id then
        return RemoveInstance(inv, instance_id)
    end

    if IsStackable(def) then
        local stack_key = GetStackKey(def, item_id, nil)
        local stack = inv.stacks[stack_key]
        if not stack or stack.qty < amount then return false, "not_enough" end
        stack.qty = stack.qty - amount
        if stack.qty <= 0 then inv.stacks[stack_key] = nil end
        return true
    end

    local removed = 0
    for id, inst in pairs(inv.instances) do
        if inst.base_id == item_id then
            inv.instances[id] = nil
            removed = removed + 1
            if removed >= amount then break end
        end
    end

    if removed < amount then
        return false, "not_enough"
    end
    return true
end

function INV.Count(inv, item_id)
    inv = INV.Normalize(inv)
    local def = GetDef(item_id)
    if not def then return 0 end

    local total = 0
    if IsStackable(def) then
        local stack_key = GetStackKey(def, item_id, nil)
        local stack = inv.stacks[stack_key]
        if stack then total = total + (stack.qty or 0) end
        return total
    end

    for _, inst in pairs(inv.instances) do
        if inst.base_id == item_id then total = total + 1 end
    end
    return total
end

function INV.HasInstance(inv, instance_id, base_id)
    inv = INV.Normalize(inv)
    local inst = inv.instances[instance_id]
    if not inst then return false end
    if base_id and inst.base_id ~= base_id then return false end
    return true
end

function INV.GetEntries(inv)
    inv = INV.Normalize(inv)
    local out = {}

    for _, stack in pairs(inv.stacks) do
        if stack.qty and stack.qty > 0 then
            local def = GetDef(stack.base_id)
            out[#out + 1] = {
                type = "stack",
                base_id = stack.base_id,
                stack_key = stack.stack_key,
                qty = stack.qty,
                stackable = true,
                condition = nil,
                instance_id = nil,
                def = def
            }
        end
    end

    for id, inst in pairs(inv.instances) do
        local def = GetDef(inst.base_id)
        out[#out + 1] = {
            type = "instance",
            base_id = inst.base_id,
            stack_key = nil,
            qty = 1,
            stackable = false,
            condition = inst.condition,
            instance_id = id,
            mods = inst.mods,
            custom_name = inst.custom_name,
            equipped = inst.equipped,
            def = def
        }
    end

    return out
end

function INV.CalcWeight(inv)
    inv = INV.Normalize(inv)
    local total = 0
    for _, entry in ipairs(INV.GetEntries(inv)) do
        local def = entry.def
        local w = def and def.wg or 0
        total = total + (w * (entry.qty or 1))
    end
    return total
end

function INV.BuildPayload(state)
    local inv = INV.Normalize(state and state.inventory)
    local categories = { "weapons", "apparel", "aid", "ammo", "misc", "notes" }
    local items_by_category = { weapons = {}, apparel = {}, aid = {}, ammo = {}, misc = {}, notes = {} }
    local equipped_items = { weapon = nil, armor_body = nil, armor_head = nil }

    local function BuildEquipped(instance_id)
        if not instance_id then return nil end
        local inst = inv.instances and inv.instances[instance_id]
        if not inst then return nil end
        local def = GetDef(inst.base_id) or {}
        local name = inst.custom_name or def.name or inst.base_id
        local cnd = inst.condition or def.cnd
        local value = def.value or 0
        if cnd ~= nil and INV.CalcValue then
            local scaled = INV.CalcValue(def, cnd)
            if scaled ~= nil then value = scaled end
        end
        return {
            item_id = inst.base_id,
            instance_id = instance_id,
            name = name,
            icon = def.icon,
            category = def.category,
            cnd = cnd,
            max_cnd = def.cnd or 100,
            value = value,
            weight = def.wg or 0
        }
    end

    for _, entry in ipairs(INV.GetEntries(inv)) do
        local def = entry.def or {}
        local cat = def.category or "misc"
        if not items_by_category[cat] then
            items_by_category[cat] = {}
        end

        local name = entry.custom_name or def.name or entry.base_id
        local actions = def.actions or {}
        if cat == "aid" then
            actions = { "use", "drop", "inspect" }
        elseif cat == "weapons" or cat == "apparel" then
            actions = { "equip", "drop", "inspect", "repair", "mod" }
        end

        local item_value = def.value or 0
        if entry.instance_id and entry.condition ~= nil and INV.CalcValue then
            local scaled = INV.CalcValue(def, entry.condition)
            if scaled ~= nil then item_value = scaled end
        end

        items_by_category[cat][#items_by_category[cat] + 1] = {
            item_id = entry.base_id,
            instance_id = entry.instance_id,
            stack_key = entry.stack_key,
            qty = entry.qty,
            stackable = entry.stackable,
            name = name,
            icon = def.icon,
            desc = def.desc,
            info = def.info,
            category = cat,
            weight = def.wg or 0,
            value = item_value,
            cnd = entry.condition or def.cnd,
            max_cnd = def.cnd or 100,
            equipped = entry.equipped or false,
            actions = actions
        }
    end

    return {
        open = true,
        categories = categories,
        items = items_by_category,
        carry_weight = {
            current = INV.CalcWeight(inv),
            max = state and state.carry_weight_max or 0
        },
        special = state and state.special or nil,
        derived = {
            carry_weight_max = state and state.carry_weight_max or 0,
            melee_damage = state and state.melee_damage or 0,
            crit_chance = state and state.crit_chance or 0,
            poison_resist = state and state.poison_resist or 0,
            rad_resist = state and state.rad_resist or 0,
            skill_rate = state and state.skill_rate or 0,
            reload_speed = state and state.reload_speed or 0,
            implant_limit = state and state.implant_limit or 0
        },
        equipped = state and state.equipped or {},
        equipped_items = {
            weapon = state and state.equipped and BuildEquipped(state.equipped.weapon_instance_id) or nil,
            armor_body = state and state.equipped and BuildEquipped(state.equipped.armor_body_instance_id) or nil,
            armor_head = state and state.equipped and BuildEquipped(state.equipped.armor_head_instance_id) or nil
        },
        sort = { key = "name", dir = "asc" }
    }
end
