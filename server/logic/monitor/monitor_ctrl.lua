local skynet = require("skynet")
local isOpenDebug = skynet.getenv("isUseMonitor")
function __MONITOR(funcName, isEnd)
    if not isOpenDebug then return end

    local context = require("common.context")
    context.sendS2S(SERVICE.MONITOR, "proFunc", funcName, isEnd)
end