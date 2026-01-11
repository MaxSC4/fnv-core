CONTAINER_STORE = {}

local function Key(container_id)
    return "container_" .. tostring(container_id)
end

function CONTAINER_STORE.Load(container_id)
    local raw = PDATA.Get(Key(container_id))
    if type(raw) == "string" then
        if JSON and JSON.parse then
            local ok, decoded = pcall(JSON.parse, raw)
            if ok and type(decoded) == "table" then
                if decoded.instances and decoded.instances._empty then
                    decoded.instances = {}
                end
                return INV.Normalize(decoded)
            end
        end
    elseif type(raw) == "table" then
        if raw.instances and raw.instances._empty then
            raw.instances = {}
        end
        return INV.Normalize(raw)
    end
    return INV.New()
end

function CONTAINER_STORE.Save(container_id, inv)
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

    if next(instances) == nil then
        instances = { _empty = true }
    end

    local persist = {
        _version = normalized._version or 2,
        next_instance_id = normalized.next_instance_id or 1,
        stacks = stacks,
        instances = instances
    }

    PDATA.Set(Key(container_id), persist)
end
