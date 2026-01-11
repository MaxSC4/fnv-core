INV_STORE = {}

local function Key(player_id)
    return "inv_" .. tostring(player_id)
end

function INV_STORE.Load(player_id)
    local raw = PDATA.Get(Key(player_id))
    if type(raw) == "string" then
        local decoded = JSON.parse(raw)
        if type(decoded) == "table" then
            return INV.Normalize(decoded)
        end
    elseif type(raw) == "table" then
        return INV.Normalize(raw)
    end
    return INV.New()
end

function INV_STORE.Save(player_id, inv)
    local normalized = INV.Normalize(inv)

    local stacks = {}
    for stack_key, stack in pairs(normalized.stacks or {}) do
        if stack and stack.base_id and stack.qty and stack.qty > 0 then
            stacks[stack_key] = {
                base_id = stack.base_id,
                qty = stack.qty,
                stack_key = stack.stack_key
            }
        end
    end

    local instances = {}
    for id, inst in pairs(normalized.instances or {}) do
        if inst and inst.base_id then
            local out = {
                base_id = inst.base_id,
                condition = inst.condition,
                equipped = inst.equipped
            }
            if inst.custom_name then out.custom_name = inst.custom_name end
            if inst.extra then out.extra = inst.extra end
            if inst.mods and next(inst.mods) ~= nil then
                out.mods = inst.mods
            end
            instances[tostring(id)] = out
        end
    end

    local persist = {
        _version = normalized._version or 2,
        next_instance_id = normalized.next_instance_id or 1,
        stacks = stacks,
        instances = instances
    }

    PDATA.Set(Key(player_id), persist)
end
