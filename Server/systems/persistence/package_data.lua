PDATA = {}

function PDATA.GetAll()
    return Package.GetPersistentData() or {}
end

function PDATA.Get(key)
    local all = PDATA.GetAll()
    return all[key]
end

function PDATA.Set(key, value)
    Package.SetPersistentData(key, value)
end
