BOOT = { started = false }

function BOOT.Start()
    if BOOT.started then
        LOG.Warn("BOOT already started (guard)")
        return
    end
    BOOT.started = true

    AUTOSAVE.Start()
    if AP and AP.Start then
        AP.Start()
    end

    LOG.Info("Core booted")
end
