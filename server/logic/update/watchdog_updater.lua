--[[
    该文件必须在agent_mgr服务上执行，限于更新agent
    首先通过调试控制台的list命令获取agent_mgr服务地址
    然后执行以下命令:
    连接debug端口 telnet 127.0.0.1 5051
    inject :01000010 ./logic/update/watchdog_updater.lua
]]
local codecache = require("skynet.codecache")
local hotfix = require("common.hotfix")
local context = require("common.context")
local configUpdater = require("update.config_updater")

local Updater = {}

--清理代码缓存，如果只是修复内存状态，没有更新代码，则不要调用
--codecache.clear()

local socketMsg = _P.socket.socketMsg



--更新配置
-- local configs = {
--     "goods"
-- }
-- local cachedConfigs = command.getConfigs()
-- configUpdater.update(agents, cachedConfigs, configs)

local clientMsg = hotfix.getupvalue(socketMsg.data, "clientMsg")

local skynet = require("skynet")
local netpack = require("netpack")
local protoMap = require("proto_map")
local logger = require("log")


function clientMsg.dispatch(c, requestId, protoId, msg, sz)
	local proto = protoMap.protos[protoId]
	if proto == nil or proto.type ~= PROTO_TYPE.C2S then
		logger.Errorf("invalid proto id[0x%x]", protoId)
		clientMsg.send(c.client, requestId, protoId, SystemError.protoNotExisits)
		return
	end
	if not c.agent and proto.service ~= SERVICE.AUTH then
		clientMsg.send(c.client, requestId, protoId, SystemError.notLogin)
		return
	end
	c.activeTime = skynet.time()
	if proto.service then
		if proto.id == M_Auth.heartbeat.id then
			clientMsg.send(c.client, requestId, protoId, SystemError.success)
			if c.agent then
				skynet.send(c.agent, "lua", "gc")
			end
			return
		end
		skynet.send(proto.service, "lua", "redirect", c.client, netpack.tostring(msg, sz))
		return
	end
	skynet.send(c.agent, "lua", "redirect", c.client, netpack.tostring(msg, sz))
end


