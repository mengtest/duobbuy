local skynet = require("skynet")
local logger = require("log")
local json = require("json")
require("proto_map")
local configs = require("config.cache")
local context = require("common.context")

local agents = {}
local clientsByRoleId = {}
local logoutingClients = {}

local command = require("command_base")

local agentPool = {}
local function initAgentPool()
	local count = skynet.getenv("agentInitCount")
	for i = 1, count do
		local agent = skynet.launch("snlua", "agent")
		context.callS2S(agent, "init", configs)
		agentPool[#agentPool + 1] = agent
	end
	collectgarbage("collect")
end

local function initAgent(roleId, client, requestId, accountInfo)
	local agent
	if #agentPool > 0 then
		agent = table.remove(agentPool, #agentPool)
	else
		agent = skynet.launch("snlua", "agent")
		context.callS2S(agent, "init", configs)
	end

	context.sendS2S(agent, "login", roleId, client, requestId, accountInfo, skynet.self())
	return agent
end

function command.getAgentPool()
	return agentPool
end

function command.getAgents()
    return agents
end

function command.getConfigs()
    return configs
end

function command.updateConfigs(updates)
	for k, v in pairs(updates) do
		configs[k] = v
	end
end

function command.login(roleId, client, requestId, accountInfo)
    local agent = initAgent(roleId, client, requestId, accountInfo)
    if logoutingClients[client] then
        logoutingClients[client] = nil
        context.callS2S(agent, "logout")
        skynet.kill(agent)
        return
    end
    agents[client] = agent
    clientsByRoleId[roleId] = client
    context.callS2S(SERVICE.WATCHDOG, "setAgent", client, agent, roleId)
    logger.Infof("initAgent %d, %x, %d, 0x%0x", roleId, client, requestId, agent)
end

function command.logout(roleId, client)
    local agent = agents[client]
    if agent then
        context.callS2S(agent, "logout")
        skynet.kill(agent)
        agents[client] = nil
        clientsByRoleId[roleId] = nil
    else
        logoutingClients[client] = roleId
    end
end

function command.getOnlineState(roleIds)
	local states = {}
	for _, roleId in pairs(roleIds) do
		states[roleId] = clientsByRoleId[roleId] ~= nil
	end
	return states
end

function command.getAddressOfRole(roleId)
	local client = clientsByRoleId[roleId]
	if client then
		return agents[client]
	end
end

local isRegistered = false
-- 状态注册
function command.notifySerivceStatus(serverName)
    isRegistered = true
end

local function registerSerivce()
    if not isRegistered then
        context.sendS2S(SERVICE.AUTH, "notifySerivceStatus", SERVICE.AGENT)
        skynet.timeout(100, function() registerSerivce() end)
    end
end

local function printAgentInfo()
	skynet.timeout(3000, function() printAgentInfo() end)
	
	print("agent num:", table.nums(agents))
end

skynet.start(function()
	initAgentPool()
	skynet.register(SERVICE.AGENT)
	print("agent server start")
	-- printAgentInfo()
	skynet.timeout(100, function() registerSerivce() end)
 end)
