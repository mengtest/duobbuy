local skynet  	= require("skynet")
local logger  	= require("log")
local json 		= require("json")
local md5    	= require("md5")
local context 	= require("common.context")
local dbHelp = require("common.db_help")
local activity  = require("service_base")
local language 	= require("language.language")

local queue = require("skynet.queue")
local queueEnter = queue()

local logConst = require("game.log_const")
local roleConst = require("role.role_const")
local serverId = skynet.getenv("serverId")

local activityStatus = require("activity.activity_const").activityStatus
local activityTime = require("activity.activity_const").activityTime
local conf = require("sharedata.corelib")
local markdirty = conf.host.markdirty
local miscOnlineConfig = {}


local command 	= activity.command

-- 状态注册
function command.notifySerivceStatus(serverName)
    isRegistered = true
end

local isRegistered = false
local function registerSerivce()
    if not isRegistered then
        context.sendS2S(SERVICE.AUTH, "notifySerivceStatus", SERVICE.MISC)
		isRegistered = true
    end
end

local function updateConfigs()
	local agents = context.callS2S(SERVICE.AGENT, "getAgents")
	local agentPool = context.callS2S(SERVICE.AGENT, "getAgentPool")
	local cachedConfigs = context.callS2S(SERVICE.AGENT, "getConfigs")
    local updated = {}
    local configname = "misc_online_config"
    local oldValue = cachedConfigs[configname]
    local newValue = conf.host.new(miscOnlineConfig)
    if oldValue then
        markdirty(oldValue)
    end

    updated[configname] = newValue
    context.callS2S(SERVICE.AGENT, "updateConfigs", updated)
    
    for _, agent in pairs(agents) do
        context.sendS2S(agent, "updateConfigs", updated)
    end
    for _, agent in pairs(agentPool) do
        context.sendS2S(agent, "updateConfigs", updated)
    end
end

local function initConfig()
	local data = {
		method = "getMiscOnlineConfig",
		serverId = serverId,
	}
	local result = context.callS2S(SERVICE.RECORD, "callDataToCenter", data)
	if not result then 
		skynet.timeout(100, function()
			initConfig()
		end)
	end

	result = json.decode(result)
	assert(result and result.errorCode == 0)
	local configs = result.data
	for _,miscOnlineData in pairs(configs) do
		local miscOnlineVO = {}
		miscOnlineVO.type = tonumber(miscOnlineData.type)
		miscOnlineVO.name = miscOnlineData.name
		miscOnlineVO.online_time = tonumber(miscOnlineData.online_time)
		miscOnlineVO.award_info = miscOnlineData.award_info
		miscOnlineVO.help = miscOnlineData.help
		miscOnlineConfig[miscOnlineVO.type] = miscOnlineVO
	end
	updateConfigs()
	
	registerSerivce()
	logger.Infof("initConfig() getMiscOnlineConfig miscOnlineConfig:%s", dumpString(miscOnlineConfig))
end

function command.changeMiscOnlineConfig()
	initConfig()
end

function activity.onStart()
	skynet.register(SERVICE.MISC)
	skynet.timeout(2 * 100, function()
		-- initConfig()
	end)
	print("misc svc start")
	registerSerivce()
end


activity.start()