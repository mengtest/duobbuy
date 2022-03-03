local skynet = require("skynet")
local logger = require("log")
local clientHelper = require("common.client_helper")
local context = {}
context.states = {}

local filerDebug = {
    ["getPathCallback"] = 1,
    ["getPath"] = 1,
    ["sendS2C"] = 1,
    ["sendS2S"] = 1,
    ["sendMultiS2C"] = 1,
    ["moveByPath"] = 1,
    ["proFunc"] = 1,
}
local function recordProto(roleId, proto, response)
    if proto.log == PROTO_LOG.ALL then
        logger.Game("player_op", {roleId = roleId, protoId = proto.id, response = response})
    end
    if proto.log ~= PROTO_LOG.NONE then
        logger.Debugf("send response[%s], desc = [%s]", proto.response, proto.desc)
    end
end

function context.sendS2S(address, cmd, ...)
    -- if not filerDebug[cmd] then
    --     logger.P("sendS2S address = ".. address .. ", cmd = " .. cmd .. " other = ", ...)
    -- end
	skynet.send(address, "lua", cmd, ...)
end

function context.callS2S(address, cmd, ...)
    -- if not filerDebug[cmd] then
    --     logger.P("callS2S address = ".. address .. ", cmd = " .. cmd .. " other = ", ...)
    -- end
	return skynet.call(address, "lua", cmd, ...)
end

function context.sendS2C(roleId, proto, data)
    if roleId then
        -- recordProto(roleId, proto, data)
        context.sendS2S(SERVICE.WATCHDOG, "sendS2C", roleId, clientHelper.pack(0, proto, 0, data))
    end
end

function context.sendMultiS2C(roleIds, proto, data)
    if roleIds and next(roleIds) then
        -- recordProto(roleId, proto, data)
        context.sendS2S(SERVICE.WATCHDOG, "sendMultiS2C", roleIds, clientHelper.pack(0, proto, 0, data))
    end
end

function context.castS2C(channelId, proto, data, exclude, excludeMap)
	context.sendS2S(SERVICE.WATCHDOG, "publish", channelId, clientHelper.pack(0, proto, 0, data), exclude, excludeMap)
end

function context.timeoutCall(address, timeout, cmd, ...)
	return skynet.call(address, "lua", cmd, ...)
end

function context.responseC2S(client, requestId, proto, ec, data)
    clientHelper.send(client, requestId, proto, ec, data)
end

function context.roomCast(roleId, proto, data, exclude)
    if context.catchFishSvc then
        context.sendS2S(context.catchFishSvc, "cast", roleId, proto, data, exclude)
    end
end

--[[
    跨服务访问agent的模块函数
    @param roleId       agent对应的角色ID
    @param modCtrlPath  对应模块的ctrl文件位置，如：mail.mail_ctrl
    @param funcName     要访问的函数名
    @param ...          传给要访问函数的参数
]]
function context.callAgentFunc(roleId, modCtrlPath, funcName, ...)
    if not roleId or type(roleId) ~= "number" then 
        logger.Errorf("modCtrlPath:%s funcName:%s traceback:%s", modCtrlPath, funcName, debug.traceback())
        return SystemError.argument
    end
    local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
    if not agentAdress then
        logger.Errorf("context.callAgentFunc(roleId, modCtrlPath, funcName, ...) modCtrlPath:%s funcName:%s roleId:%s", modCtrlPath, funcName, roleId)
        return SystemError.argument
    end
    return context.callS2S(agentAdress, "doModLogic", roleId, modCtrlPath, funcName, ...)
end

function context.sendAgentFunc(roleId, modCtrlPath, funcName, ...)
    if not roleId or type(roleId) ~= "number" then 
        logger.Errorf("modCtrlPath:%s funcName:%s traceback:%s", modCtrlPath, funcName, debug.traceback())
        return SystemError.argument
    end
    local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
    if not agentAdress then
        logger.Errorf("context.sendAgentFunc(roleId, modCtrlPath, funcName, ...) modCtrlPath:%s funcName:%s roleId:%s", modCtrlPath, funcName, roleId)
        return SystemError.argument
    end
    context.sendS2S(agentAdress, "doModLogic", roleId, modCtrlPath, funcName, ...)
end
return context