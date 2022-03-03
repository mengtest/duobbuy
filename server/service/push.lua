local skynet  	= require("skynet")
local json 		= require("json")
local push   	= require("service_base")
local context 	= require("common.context")
local command   = push.command

local oneHourSec = 3600
local oneDaySec = 86400
local maxPushDay = 30
local maxPushSec = oneDaySec * maxPushDay

local pushList = {}

local function handlePushList()
	local now = skynet.now()
	local sendList = {}
	for roleId, info in pairs(pushList) do
		if now - info.logoutTime >= oneDaySec and (not info.pushTime or now - info.pushTime  >= oneDaySec) then
			info.pushTime = now
			sendList[#sendList+1] = roleId
		end
		if now - info.logoutTime >= maxPushSec then
			pushList[roleId] = nil
		end
	end
	if #sendList > 0 then
		command.sendOfflinePush(sendList)
	end
end

local function circlePush()
	skynet.timeout(oneHourSec * 100, function()
		circlePush()
		handlePushList()
	end)
end

function command.addLogoutRole(roleId)
	pushList[roleId] = {logoutTime = skynet.now()}
end

function command.delLogoutRole(roleId)
	pushList[roleId] = nil
end

function command.sendOfflinePush(roleIds)
	local data = {
		method = "sendOfflinePush",
		roleIds = json.encode(roleIds),
	}
	context.sendS2S(SERVICE.RECORD, "sendDataToCenter", data)
end

function push.onStart()
	skynet.register(SERVICE.PUSH)
	circlePush()
	print("push server start")
end

push.start()