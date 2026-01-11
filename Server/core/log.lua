LOG = {}

function LOG.Info(msg)  Console.Log("[FALLOUT] " .. msg) end
function LOG.Warn(msg)  Console.Log("[FALLOUT][WARN] " .. msg) end
function LOG.Err(msg)   Console.Log("[FALLOUT][ERR] " .. msg) end
