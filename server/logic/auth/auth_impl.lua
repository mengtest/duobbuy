local json = require("json")
local skynet = require("skynet")
local logger = require("log")
local context = require("common.context")
local authCtrl = require("auth.auth_ctrl")

local authImpl = {}

function authImpl.login(client, data, requestId)
	local ec, result = authCtrl.login(client, data, requestId)
	return ec, result
end

function authImpl.createRole(client, data, requestId)
	local ec = authCtrl.createRole(client, data, requestId)
	if ec ~= SystemError.forward then
		context.sendS2S(SERVICE.WATCHDOG, "loginFailure", client)
	end
	return ec
end

function authImpl.getServerTime()
	return SystemError.success, {time = skynet.time()} 
end

return authImpl