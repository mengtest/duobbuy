local skynet = require("skynet")
local logger = require("log")
local context = require("common.context")

local ServiceRegister = {}

-- 是否在维护
local isServerMaintenance = true
local SysServerMaintenance = false

-- 所有服务状态
local SerivceStatus = {}


function ServiceRegister.init()
	-- 关注的服务 一定要等待这些服务相关的业务加载完成后才允许玩家登陆
	SerivceStatus[SERVICE.AGENT] = false
	SerivceStatus[SERVICE.ACTIVITY] = false
	SerivceStatus[SERVICE.MISC] = false
	SerivceStatus[SERVICE.MONITOR] = false
end

-- 注册服务 必须将所有关注的服务都注册了之后才可以开放入口
function ServiceRegister.registerSerivce(serivceName)
	SerivceStatus[serivceName] = true

	-- 收到了消息一定要给一个回执
	context.sendS2S(serivceName, "notifySerivceStatus", serivceName)
	local notOpenSerivce
	for k, v in pairs(SerivceStatus) do
		if v == false then
			notOpenSerivce = (notOpenSerivce or " ") .. k .. " "
		end
	end
	logger.Debugf("注册了服务 = %s 等待:%s", serivceName, notOpenSerivce or "---")
	
	if not notOpenSerivce then
		logger.Debugf("所有服务都已注册 登陆入口开放")
		print("所有服务都已注册 登陆入口开放")
		isServerMaintenance = false
	end
end

function ServiceRegister.isOpenServer()
	return not isServerMaintenance and not SysServerMaintenance
end

function ServiceRegister.closeServer(isClose)
	SysServerMaintenance = isClose
end

return ServiceRegister