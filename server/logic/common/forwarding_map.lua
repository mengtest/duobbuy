local roleCtrl = require("role.role_ctrl")
local skynet = require("skynet")
local context = require("common.context")

local forwardMsg = {}
local function func(cmd, roleId, data, isSend, preconditionFunc, callBackFunc)
    if roleCtrl.getBaseInfo().curSvcAddress == nil or roleCtrl.getBaseInfo().curSvcAddress == skynet.self() then
        return SystemError.illegalOperation
    end
    if preconditionFunc then
        local ec = preconditionFunc(roleId, data)
        if ec ~= SystemError.success then
            return ec
        end
    end
    if isSend then
        context.sendS2S(roleCtrl.getBaseInfo().curSvcAddress, cmd, roleId, roleCtrl.getBaseInfo().curCopyWorldId, data)
        if callBackFunc then return callBackFunc() end
        return SystemError.success
    else
        local ec, retData, callBackData = context.callS2S(roleCtrl.getBaseInfo().curSvcAddress, cmd, roleId, roleCtrl.getBaseInfo().curCopyWorldId, data)
        if ec ~= SystemError.success then
            return ec
        end
        if callBackFunc then
            return callBackFunc(roleId, callBackData), retData
        else
            return ec, retData
        end
    end
end

function forwardMsg.getForwardFunc(cmd, isSend, preconditionFunc, callBackFunc)
    return function(roleId, data)
                return func(cmd, roleId, data, isSend, preconditionFunc, callBackFunc)
            end
end

return forwardMsg