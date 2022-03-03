require("skynet.manager")
local skynet = require("skynet")
local netpack = require("netpack")
local socketdriver = require("socketdriver")
local harbor = require("skynet.harbor")
local logger = require("log")
local ProtoRecorder = require("recorder.proto_recorder")
local protobuf = require("protobuf")

local clientHelper = require("common.client_helper")
local context = require("common.context")
require("errorcode")
local protoMap = require("proto_map")

local csend = socketdriver.send
local lsend = socketdriver.lsend

local port = tonumber(skynet.getenv("port"))			--对外服务端口
local maxClient =  tonumber(skynet.getenv("maxClient"))	--最大连接数
local maxLogining =  tonumber(skynet.getenv("maxLogining")) or 10	--最大同时登录人数
local heartbeatInterval = tonumber(skynet.getenv("heartbeatInterval")) --心跳检查间隔
local recordPath = skynet.getenv("recordPath") --协议记录数据文件保存文件夹
local isRecordRoot = skynet.getenv("isRecordRoot")
local flushInterval = tonumber(skynet.getenv("flushInterval")) or 5 --协议记录数据同步到磁盘间隔
local openLoginLimit = tonumber(skynet.getenv("openLoginLimit")) or 1
local loginWhiteIps = skynet.getenv("loginWhiteIps") or ""
print("-------------------------------------")
print("loginWhiteIps White IPs: " .. loginWhiteIps)
print("-------------------------------------")
loginWhiteIps = string.split(loginWhiteIps, ",")
for i, ip in ipairs(loginWhiteIps) do
	loginWhiteIps[string.trim(ip)] = true
end

local socket					--监听服务套接字
local queue					--消息缓存队列
local close

local clientCount = 0		--当前客户端连接数
local clients = {}			--客户端连接信息{fd, client, ip, agent, waitting}
local waittings = {}		--正在等待登录的玩家信息
local loginingCount = 0		--正在登录玩家数量
local roles = {}			--登录玩家信息

local totalLoginCostTime = 0
local totalLoginCount = 0
local loginCostTime = 3	--登录平均消耗时长

local curChannelId = 0
local channels = {}		--广播信息发送频道

local requestCount = 0   --请求量
local responseCount = 0   --响应量
local eventCount = 0 		--事件量

local clientMsg = {}

local clientpack = clientHelper.pack

local function sendBuffer(client, buffer)
	local fd = client
	if not clients[fd] then
		return
	end
	csend(fd, buffer)
end

local function getWaittingInfo(c)
	local info = {waittings = #waittings, selfPos = 0}
	for index, client in pairs(waittings) do
		if client == c.client then
			info.selfPos = index
			break
		end
	end
	info.remainTime = info.selfPos * loginCostTime
	return {waittingInfo = info}
end

local function addWaitting(c)
	c.waitting = true
	waittings[#waittings + 1] = c.client
end

local function removeWaitting(c)
	for index, client in pairs(waittings) do
		if client == c.client then
			table.remove(waittings, index)
			break
		end
	end
	c.waitting = nil
end

local function calcAvgLoginCostTime(costTime)
	totalLoginCostTime = totalLoginCostTime + costTime
	totalLoginCount = totalLoginCount + 1
	loginCostTime = totalLoginCostTime / totalLoginCount
end

local command = setmetatable({}
	, { __gc = function() netpack.clear(queue) end }		--网关服务退出时清理消息队列关联内存
)

--[[
	玩家登录时会调用该接口，添加角色到对应服务器中
	@param roleId 角色ID
	@param client 客户端发送数据服务地址
]]
function command.login(roleId, client)
	roles[roleId] = client
    local c = clients[client]
    if c then
        if c.isLogining then
            c.isLogining = nil
            loginingCount = loginingCount - 1
            local costTime = skynet.time() - c.loginTime
            calcAvgLoginCostTime(costTime)
        end
        c.roleId = roleId
    end
end

function command.loginFailure(client)
	local c = clients[client]
	if c and c.isLogining then
		c.isLogining = nil
		loginingCount = loginingCount - 1
	end
end

--[[
	玩家离线时会调用该接口，从对应服务器移除该角色
	@param roleId 角色ID
	@param client 客户端发送数据服务地址
	@parma serverId 服务器ID
]]
function command.logout(roleId, client, serverId)
	-- logger.Debugf("roleId:%d, client:0x%x, serverId:%d", roleId or 0, client, serverId)
	-- roles[roleId] = nil
end

--[[
	关联agent与client
	@param fd 客户端发送数据服务地址
	@parma agent 单个玩家游戏逻辑代理服务
	@param roleId 角色ID
]]
function command.setAgent(client, agent, roleId)
    local fd = client
	local c = clients[fd]
    if c then
        c.agent = agent
        logger.Infof("写入agent地址 client = %s, agent = %s", client, agent)
        if recordPath and isRecordRoot then
            c.recorder = ProtoRecorder.new()
            if not c.recorder:init(recordPath .. roleId .. ".pdt", flushInterval, nil) then
                c.recorder = nil
            end
        end
    end
end

--[[
	创建新的广播频道
	@param channelId 如果不为nil，则创建频道时以该值作为频道ID，否则自动分配
	@result 频道ID
]]
function command.newChannel(channelId)
	if not channelId then
		curChannelId = curChannelId + 1
		channelId = curChannelId
	end
	channels[channelId] = {}
	return channelId
end

--[[
	创建多个新的广播频道
	@param count 频道个数
	@result 频道ID列表
]]
function command.newChannels(count)
	local channelIds = {}
	for i = 1, count do
		local channelId = command.newChannel()
		channelIds[i] = channelId
	end
	return channelIds
end

--[[
	删除广播频道
	@param channelId 频道ID、
]]
function command.delChannel(channelId)
	channels[channelId] = nil
end

--[[
	删除多个广播频道
	@param channelIds 频道列表
]]
function command.delChannels(channelIds)
	for _, channelId in pairs(channelIds) do
		command.delChannel(channelId)
	end
end

--[[
	订阅频道
	@param channelId 频道ID
	@param roleId 订阅频道的成员
	@param create 如果没找到指定的频道，标示是否创建该频道
]]
function command.subscribe(channelId, roleId, create)
	local channel = channels[channelId]
	if not channel then
		if create then
			channel = {}
			channels[channelId] = channel
		else
			return
		end
	end
	channel[roleId] = true
end

--[[
	订阅频道
	@param channelId 频道ID
	@param roleId 订阅频道的成员
	@param destroy 如果此频道中已经没有成员，标示是否销毁该频道
]]
function command.unsubscribe(channelId, roleId, destroy)
	local channel = channels[channelId]
	if not channel then
		return
	end
	channel[roleId] = nil
	if destroy and table.empy(channel) then
		channels[channelId] = nil
	end
end

--[[
	发布频道消息
	@param channelId 频道ID，如果为nil，则向全服广播
	@param buffer 消息数据
	@param exclude 是否排除某个成员接收信息
]]
function command.publish(channelId, buffer, exclude, excludeMap)
	excludeMap = excludeMap or {}
	if channelId then
        local channel = channels[channelId]
        if not channel then
            return
        end

        for roleId in pairs(channel) do
            if roleId ~= exclude and not excludeMap[roleId] then
                local client = roles[roleId]
                if client then
                    eventCount = eventCount + 1
                    sendBuffer(client, buffer)
                end
            end
        end
    else
        for roleId, _ in pairs(roles) do
            if roleId ~= exclude and not excludeMap[roleId] then
                local client = roles[roleId]
                if client then
                    eventCount = eventCount + 1
                    sendBuffer(client, buffer)
                end
            end
        end
    end
end

function command.sendS2CByClient(client, buffer)
    responseCount = responseCount + 1
    sendBuffer(client, buffer)
end

function command.sendMultiByClients(clients, buffer)
	for _, client in pairs(clients) do
		command.sendS2CByClient(client, buffer)
	end
end

function command.sendS2C(roleId, buffer)
	local client = roles[roleId]
	if client then
		command.sendS2CByClient(client, buffer)
	end
end

function command.sendMultiS2C(roleIds, buffer)
	for _, roleId in pairs(roleIds) do
		local client = roles[roleId]
		if client then
			command.sendS2CByClient(client, buffer)
		end
	end
end

function command.responseC2S(client, buffer)
	responseCount = responseCount + 1
	sendBuffer(client, buffer)
end


--[[
	踢掉指定客户端，关闭连接
	@param client 客户端发送数据服务地址
]]
function command.kick(client)
	local fd = client
    close(fd)
	socketdriver.close(fd)
    return true
end

function command.kickByRoleId(roleId)
    local client = roles[roleId]
    if client then
        command.kick(client)
    end
end

-- 获取在线人数
function command.getOnlineNum()
    local num = 0
    for roleId in pairs(roles) do
        num = num + 1
    end
    return num
end

-- 获取client ip
function command.getClientIp(client)
	local c = clients[client]
	if c then
		return c.ip
	end
end

skynet.info_func(function()
	return {
		requestCount = requestCount,
		responseCount = responseCount,
		eventCount = eventCount,
	}
end)

skynet.dispatch("lua", function(session, address, cmd, ...)
	local func = assert(command[cmd], cmd)
    -- if cmd == "publish" then
    --     print("dispatch", ...)
    -- end
	local ret = func(...)
	if session > 0 then
		skynet.ret(skynet.pack(ret))
	end
end)

------------------------------------------------------

local function checkClientActive()
	local now = skynet.time()
	for _, c in pairs(clients) do
		if now - c.activeTime > heartbeatInterval then
        	logger.Infof("client[0x%0x], roleId[%d] is timeout", c.client, c.roleId or 0)
			clientMsg.send(c.client, 0, M_Auth.onOffline.id, 0, {type = 1, messages = "心跳超时"})
			command.kick(c.client)
		end
	end

	skynet.timeout(5 * 100, checkClientActive)
end

-----------------------------------------------
local _isRecord = false
local _recordInterval = nil
local _recordRole = 0
local _recordNumber = 0
function command.setMsgRecord(isRecord, recordInterval, roleId, number)
	isRecord = isRecord or false
	recordInterval = recordInterval or 30
	roleId = roleId or 0
	number = number or 0
	if recordInterval <= 0 then 
		recordInterval = 30
	end
	
	_isRecord = isRecord
	_recordInterval = recordInterval
	_recordRole = roleId
	_recordNumber = number
end

local msgRecord = {}
local roleRecord = {}
function clientMsg.recordMsg(c, protoId) 
	if not _isRecord then 
		return
	end

	local now = skynet.time()
	if not msgRecord.timestamp or not msgRecord.protoInfo or not msgRecord.roleInfo then 
		msgRecord.timestamp = now
		msgRecord.protoInfo = {}
		msgRecord.roleInfo = {}
	end 
	if (msgRecord.timestamp + _recordInterval) < now then 
		logger.Pf("clientMsg.recordMsg(c, protoId) time:%s msgRecord:%s _recordRole:%s roleRecord:%s", (now - msgRecord.timestamp), dumpString(msgRecord), _recordRole, dumpString(roleRecord))
		msgRecord = {}
		msgRecord.timestamp = now
		msgRecord.protoInfo = {}
		msgRecord.roleInfo = {}
		roleRecord = {}

		_recordNumber = _recordNumber - 1
		if _recordNumber <= 0 then _isRecord = false return end
	end
	msgRecord.protoInfo[protoId] = (msgRecord.protoInfo[protoId] or 0) + 1
	local key = c.roleId or c.ip
	msgRecord.roleInfo[key] = (msgRecord.roleInfo[key] or 0) + 1
	if type(key) == "number" and _recordRole == key then 
		roleRecord[key] = roleRecord[key] or {}
		roleRecord[key][protoId] = (roleRecord[key][protoId] or 0) + 1
	end
end 

--[[
	客户端数据分派处理
]]
local statistics = {}
function clientMsg.dispatch(c, requestId, protoId, msg, sz)
	if openLoginLimit == 1 then 
		local ip = c.ip or "1:1"
		ip = string.split(ip, ":")[1]
		if not loginWhiteIps[ip] then 
			clientMsg.send(c.client, requestId, protoId, SystemError.ServerMaintenance)
			return
		end
	end
	-- logger.Infof("client[0x%0x], roleId[%d] protoId[0x%0x]", c.client, c.roleId or 0, protoId)
	requestCount = requestCount + 1
	local proto = protoMap.protos[protoId]
	if proto == nil or proto.type ~= PROTO_TYPE.C2S then
		logger.Errorf("invalid proto id[0x%x]", protoId)
		--command.kick(c.client)
		clientMsg.send(c.client, requestId, protoId, SystemError.protoNotExisits)
		return
	end
	if not c.agent and proto.service ~= SERVICE.AUTH then
		clientMsg.send(c.client, requestId, protoId, SystemError.notLogin)
		return
	end

	-- 设置链接活跃期
	local now = skynet.time()
	if protoId ~= M_CatchFish.robotHit.id and protoId ~= M_Auth.heartbeat.id then
		c.activeTime = now
		-- logger.Infof("client[0x%0x], roleId[%d] protoId[0x%0x]", c.client, c.roleId or 0, protoId)
	end
	
	-- 统计玩家请求
	clientMsg.recordMsg(c, protoId) 
	
	if proto.service then
		-- 登陆队列
		if proto.id == M_Auth.login.id then
            if isServerClose then
                clientMsg.send(c.client, requestId, protoId, SystemError.ServerMaintenance, {})
                return
            end
			if loginingCount >= maxLogining then   --检查是否达到最大同时登录人数
				if not c.waitting then  --是否已经处于等待中
					addWaitting(c)
				end
				local result = getWaittingInfo(c)
				logger.Infof("clientMsg.dispatch WaittingInfo:%s", dumpString(result))
				clientMsg.send(c.client, requestId, protoId, SystemError.success, result)
				return
			end
			removeWaitting(c)
			c.isLogining = true
			c.loginTime = skynet.time() -- c.activeTime
			loginingCount = loginingCount + 1
		elseif proto.id == M_Auth.heartbeat.id then
			clientMsg.send(c.client, requestId, protoId, SystemError.success)
			if c.agent then
				skynet.send(c.agent, "lua", "gc")
			end
			return
		end
		local buff = netpack.tostring(msg, sz)
		skynet.send(proto.service, "lua", "redirect", c.client, buff)
		return buff
	end
	local buff = netpack.tostring(msg, sz)
	skynet.send(c.agent, "lua", "redirect", c.client, buff)
	return buff
end

function clientMsg.send(client, ...)
	responseCount = responseCount + 1
	local buffer = clientMsg.pack(...)
	sendBuffer(client, buffer)
end

local buffer = "12345678"
function clientMsg.pack(requestId, protoId, ec, data)
	if not data then
		protobuf.encode_int16(buffer, 0, #buffer - 2)
		protobuf.encode_int16(buffer, 2, protoId)
		protobuf.encode_int16(buffer, 4, requestId)
		protobuf.encode_int16(buffer, 6, ec)
		return buffer
	end
	local proto = protoMap.protos[protoId]
	return clientpack(requestId, proto, ec, data)
end

function clientMsg.unpack(msg, sz)
	local protoId = protobuf.decode_int16(msg, sz, 0)
	local requestId = protobuf.decode_int16(msg, sz, 2)
	return requestId, protoId
end

--------------------------------网络消息-----------------------------------
local socketMsg = {}

--[[
	新的连接接受时调用
	@param 连接句柄
	@msg 连接的IP地址
]]
function socketMsg.open(fd, msg)
	logger.Infof("open client fd[%d] ip[%s]", fd, msg)
	if clientCount >= maxClient then
		socketdriver.close(fd)
		return
	end

	local c = {
		client = fd,
		ip = msg,
		activeTime = skynet.time(),
	}
	clients[fd] = c
	clientCount = clientCount + 1
	socketdriver.start(fd)
end

--[[
	单个数据包信息
	@param fd 连接句柄
	@param msg 消息数据
	@param sz 数据长度
]]
function socketMsg.data(fd, msg, sz)
	local c = clients[fd]
	if not c then
		return
	end
	local requestId, protoId = clientMsg.unpack(msg, sz)
	local buff = clientMsg.dispatch(c, requestId, protoId, msg, sz)
	if c.recorder and buff then
		-- printf(string.format("socketMsg.data(fd, msg, sz) requestId:%s protoId:%X", (requestId or 0), (protoId or 0)))
		local buf = "12"
		protobuf.encode_int16(buf, 0, sz)
		-- print("netpack.tostring(msg, sz, 0):"..netpack.tostring(msg, sz))
		-- buf = buf .. (netpack.tostring(msg, sz, 0) or "")
		buf = buf .. buff
		-- print("buf:"..buf)
		c.recorder:log(true, protoId, buf)
	end
end

--[[
	多个数据包信息
]]
function socketMsg.more()
	for fd, msg, sz in netpack.pop, queue do
		socketMsg.data(fd, msg, sz)
	end
end

function socketMsg.warning(fd, sz)
end

--[[
	清理连接状态信息
	@param 连接句柄
]]
close = function (fd)
    local c = clients[fd]
    if not c then
        return
    end

    if c.recorder then
        c.recorder:destroy()
    end

	if c.waitting then
        removeWaitting(c)
    end
	
	if c.isLogining then
        loginingCount = loginingCount - 1
    end

    if c.roleId then
        roles[c.roleId] = nil
    end

    clients[fd] = nil
    clientCount = clientCount - 1

    if c.agent then
        context.callS2S(SERVICE.AUTH, "castLogout", c.client)
    end
end

--[[
	连接关闭时调用
	@param 连接句柄
]]
function socketMsg.close(fd)
	-- print("socketMsg.close(fd) fd:",fd)
	logger.Infof("close %d", fd)
	close(fd)
end

--[[
	连接关闭发送错误时调用
	@param 连接句柄
	@param 错误信息
]]
function socketMsg.error(fd, msg)
	logger.Errorf("fd[%d], error msg:[%s]", fd, msg)
	close(fd)
end

skynet.register_protocol {
	name = "socket",
	id = skynet.PTYPE_SOCKET,
	unpack = function (msg, sz)
		return netpack.filter(queue, msg, sz)
	end,
	dispatch = function (_, _, q, type, ...)
		queue = q
		if type then
			local f = socketMsg[type] 
			if f then
				f(...)
			end
		end
	end
}

-----------------------------停服，数据落地------------------------------
local willKickRoleCount
local kickRoleCount
-- 登陆开关
function command.loginSwitch(isOpen)
    isServerClose = isOpen
    if isServerClose then
        willKickRoleCount = 0
        kickRoleCount = 0
    end
end

-- 踢掉所有玩家
function command.kickAllRole()
    logger.Debugf("踢掉所有玩家离开游戏")

    for roleId, client in pairs(roles) do
         if client then
            if willKickRoleCount then
                willKickRoleCount = willKickRoleCount + 1
            end
			print("kick roleId:", roleId)
            command.kick(client)
        end
    end
    if willKickRoleCount and willKickRoleCount == 0 then
        command.checkKickAllRole()
    end
end

-- 玩家确认离线
function command.checkKickAllRole()
    if not kickRoleCount then
        return
    end
    kickRoleCount = kickRoleCount + 1
    if kickRoleCount >= willKickRoleCount then
        print ("所有玩家确认数据已经落地 willKickRoleCount = " .. willKickRoleCount .. " kickRoleCount = "..kickRoleCount)
        context.sendS2S(SERVICE.SHUTDOWN_SERVER, "checkAllRoleLogout")
    end
end

-- 获取指定 IP 登陆的玩家
function command.getRoleListByIp(ip)
	local roleList = {}
	if not ip then 
		return roleList
	end

	for _,c in pairs(clients) do
		local clientIp = string.split(c.ip, ":")[1]
		if clientIp == ip and c.roleId then 
			table.insert(roleList, c.roleId)
		end
	end
	return roleList
end


-------------------------------------------------------------------------

skynet.start(function()
	socket = socketdriver.listen("0.0.0.0", port)
	socketdriver.start(socket)
	local harborId = skynet.harbor(skynet.self())
	skynet.register(SERVICE.WATCHDOG)
	context.sendS2S(harbor.queryname(SERVICE.AUTH), "watch", skynet.self())
	if heartbeatInterval then
		skynet.timeout(heartbeatInterval * 100, checkClientActive)
	end
	print("watchdog server start")
end)
