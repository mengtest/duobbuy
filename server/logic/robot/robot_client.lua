local skynet = require("skynet")
local netpack = require("netpack")
local socket = require("socket")
local httpc = require("http.httpc")
local logger = require("log")
require("functions")
local json = require("json")
local protoMap = require("proto_map")
local protobuf = require("protobuf")

local MESSAGE_HEADER_LENGTH = 4
local REQUEST_MESSAGE_HEADER_LENGTH = 6
local EVENT_MESSAGE_HEADER_LENGTH = 4
local HEARTBEAT_PROTO_ID = 0x0103

local EC_HTTP_METHOD_ERROR      = 1000
local EC_PARAM_INVILD           = 1001
local EC_NOT_SUPPORT_API_METHOD = 1002
local EC_USER_NOT_EXIST         = 1003
local EC_PWD_IS_ERROR           = 1004
local EC_SUCCESS                = 0

local TestClient = class("TestClient")

function TestClient:ctor(protos, completedCallback)
	self._requestId = 0
	self._msgHeader = {length = 0, protoId = 0}
	self._maxMsgSize = 2 ^ 16
	self._protosById = protos
	self._latestResponseTime = 0
	self._completedCallback = completedCallback
end

function TestClient:login(loginHost, loginUrl, serverId, account, password)
	--验证账号
	print ("验证账号")
	local postData = "method=login&" .. "accountName=" .. account .. "&pwd=" .. password
	local header = {["Content-Type"] = "application/x-www-form-urlencoded"}
	local statuscode, data = httpc.request("POST", loginHost, loginUrl, nil, header, postData)
	-- print ("验证账号 = ", statuscode)
	if statuscode ~= 200 or not data then
		return false
	end
	local authInfo = json.decode(data)
	-- print ("authInfo.errorCode = ", authInfo.errorCode)
	if authInfo.errorCode == EC_USER_NOT_EXIST then  --创建账号
		print ("创建账号")
		local postData = "method=register&" .. "accountName=" .. account .. "&pwd=" .. password
		local header = {["Content-Type"] = "application/x-www-form-urlencoded"}
		local statuscode, data = httpc.request("POST", loginHost, loginUrl, nil, header, postData)
		if statuscode ~= 200 or not data then
			return false
		end
		authInfo = json.decode(data)
		if authInfo.errorCode ~= EC_SUCCESS then
			return false
		end
	elseif authInfo.errorCode ~= EC_SUCCESS then
		return false
   end
   if #authInfo.data.serverList == 0 then
		return false
   end
   print ("连接游戏服")
	--连接游戏服
	local serverInfo
	for _, server in pairs(authInfo.data.serverList) do
		if tonumber(server.sid) == serverId then
			serverInfo = server
			break
		end
	end

	if not serverInfo then
		return false
	end

	self._fd = socket.open(serverInfo.addr, serverInfo.port)
	if not self._fd then
		printf("connect to %s:%d failure.", serverInfo.addr, serverInfo.port)
		return false
	end

	--登录游戏服, 获取角色
	local loginInfo = {uid = account
		, token = authInfo.data.token
		, signTime = authInfo.data.time
		-- , serverId = serverInfo.sid
		, imei = "robot"
		}
	print ("登录并获取角色")
	local result = self:request(M_Auth.login, loginInfo)
	if not result or result.errorCode ~= SystemError.success then
		printf("login to %s:%d failure. ec[%x]", serverInfo.addr, serverInfo.port, result and result.errorCode or -1)
		return false
	end

	local waittingInfo = result.data.waittingInfo
	while waittingInfo and waittingInfo.waittings > 0 do --需要等待
		if waittingInfo.selfPos > 20 then
			skynet.sleep(30 * 100)
		else
			skynet.sleep(5 * 100)
		end
		result = self:request(M_Auth.login, loginInfo)
		if not result or result.errorCode ~= SystemError.success then
			dump(result)
			printf("login to %s:%d failure. ec[%d]", serverInfo.addr, serverInfo.port, result and result.errorCode or -1)
			return false
		end
		waittingInfo = result.data.waittingInfo
	end
	local roleId = result.data.roleId
	if not roleId or roleId == 0 then
		-- 没有角色，创建角色
		print("创建角色")
		result = self:request(M_Auth.createRole, {nickname = account, avatar = math.rand(1, 5), imei = "robot"})
		if not result or result.errorCode ~= SystemError.success then
			printf("create role failure. ec[%d]", result and result.errorCode or -1)
			return false
		end
		self._account = account
		return true
	end

	--登录角色
	print ("登录角色")
	local result = self:request(M_Role.getRoleInfo)
	local result = self:request(M_CatchFish.enterRoom)
	if not result or result.errorCode ~= SystemError.success then
		printf("do roleLogin to %s:%d failure. ec[%d]", serverInfo.addr, serverInfo.port, result and result.errorCode or -1)
		return false
	end
	self._account = account
	print("登陆成功")
	return true
end

function TestClient:getAccount()
	return self._account
end

function TestClient:start(requests)
	print ("机器人开始")
	if not self:isConnected() then
		print ("if not self:isConnected() then")
		return false
	end

	self._sampleRequests = requests
	self._requestIndex = 1
	self:_sendSampleRequest()
end

function TestClient:stop(completed)
	if self._fd then
		-- print ("中断 ", debug.traceback())
		socket.close(self._fd)
		self._fd = nil
	end

	if self._completedCallback then
		self._completedCallback(self, completed)
		self._completedCallback = nil
	end
end

function TestClient:isConnected()
	return self._fd ~= nil
end

function TestClient:heartbeat(interval)
	self._hbInterval = interval
	if self._hbInterval > 0 then
		self:_onHBTimeout()
	end
end

----------------------------------------------------------------------------
function TestClient:request(proto, data)
	if not self:isConnected() then
		return
	end

	if not self:sendData(proto, data) then
		return
	end

	return self:_response()
end

function TestClient:sendData(proto, data)
	local buffer = nil
	if proto.request then
		if proto.request == "int8" then
			buffer = "1234567"
			protobuf.encode_int8(buffer, REQUEST_MESSAGE_HEADER_LENGTH, data)
		elseif proto.request == "int16" then
			buffer = "12345678"
			protobuf.encode_int16(buffer, REQUEST_MESSAGE_HEADER_LENGTH, data)
		elseif proto.request == "int32" then
			buffer = "1234567890"
			protobuf.encode_int32(buffer, REQUEST_MESSAGE_HEADER_LENGTH, data)
		else
			buffer = protobuf.encode_ex(proto.request, data, REQUEST_MESSAGE_HEADER_LENGTH)
		end
	else
		buffer = "123456"
	end
	local msgLen = string.len(buffer)
	protobuf.encode_int16(buffer, 0, msgLen - 2)
	protobuf.encode_int16(buffer, 2, proto.id)
	self._requestId = self._requestId + 1
	protobuf.encode_int16(buffer, 4, self._requestId)
	return self:send(buffer)
end

function TestClient:send(buffer)
	local ok = socket.write(self._fd, buffer)
	if not ok then
		return false
	end
	return true
end

function TestClient:read(sz)
	local ret = socket.read(self._fd, sz)
	if ret then
		return ret
	end
	return nil
end

------------------------------------------------------------------
function TestClient:_decodeHeader(buffer)
	local header = self._msgHeader
	header.length = protobuf.decode_int16(buffer, 0)
	header.protoId = protobuf.decode_int16(buffer, 2)
	return header
end

function TestClient:_decodeC2S(proto, buffer, msgLen)
	self._latestResponseTime = os.time()

	local requestId = protobuf.decode_int16(buffer, REQUEST_MESSAGE_HEADER_LENGTH - 2)
	local ec = protobuf.decode_int16(buffer, REQUEST_MESSAGE_HEADER_LENGTH)
	local data = nil
	if proto.response then
		if msgLen > REQUEST_MESSAGE_HEADER_LENGTH + 2 then
			data = self:_decodeMessage(proto.response, buffer, REQUEST_MESSAGE_HEADER_LENGTH + 2, msgLen)
		else
			data = {}
		end
	end
	if ec ~= SystemError.success then
		logger.Infof("request:%s, response error:[%s]", proto.fullname, errmsg(ec))
		return {errorCode = ec}
	end
	return {errorCode = ec, data = data}
end

function TestClient:_decodeS2C(proto, buffer, msgLen)
	local data = nil
	if msgLen > EVENT_MESSAGE_HEADER_LENGTH then
		data = self:_decodeMessage(proto.response, buffer, EVENT_MESSAGE_HEADER_LENGTH, msgLen)
	end
	return {data = data}
end

function TestClient:_onHBTimeout()
	if not self:isConnected() then
		return
	end

	local now = os.time()
	if now - self._latestResponseTime > self._hbInterval then
		self:request(M_Auth.heartbeat)
	end

	skynet.timeout(self._hbInterval * 100, handler(self, self._onHBTimeout))
end

function TestClient:_response()
	local buffer = self:read(MESSAGE_HEADER_LENGTH)
	if not buffer then
		print (buffer)
		return
	end
	local header = self:_decodeHeader(buffer)
	if header.length > self._maxMsgSize then
		print ("header.length")
		return
	end
	local proto = self._protosById[header.protoId]
	if not proto then
		print ("proto")
		return
	end

	local msgLen = header.length + 2
	if msgLen - MESSAGE_HEADER_LENGTH > 0 then 
		local bodybuffer = self:read(msgLen - MESSAGE_HEADER_LENGTH)
		if not bodybuffer then
			printf ("bodybuffer...msgLen:%s header.length:%s header.protoId:%X", msgLen, header.length, header.protoId)
			return
		end
		buffer = buffer .. bodybuffer
	end

	if proto.type == PROTO_TYPE.C2S then
		return self:_decodeC2S(proto, buffer, msgLen)
	elseif proto.type == PROTO_TYPE.S2C then
		local result = self:_decodeS2C(proto, buffer, msgLen)
		if result then
			result = self:_response()
		end
		return result
	else
		print ("error proto.type = ", proto.type)
		return
	end
end

function TestClient:_decodeMessage(response, buffer, offset, msgLen)
	if response == "int8" then
		return protobuf.decode_int8(buffer, offset)
	elseif response == "int16" then
		return protobuf.decode_int16(buffer, offset)
	elseif response == "int32" then
		return protobuf.decode_int32(buffer, offset)
	else
		local buffLen = string.len(buffer)
		if buffLen > msgLen then
			buffer = string.sub(buffer, 1, msgLen)
		end
		return protobuf.decode_ex(response, buffer, offset)
	end
end

function TestClient:_sendSampleRequest(request)
	-- printf("TestClient:_sendSampleRequest(request)")
	request = request or self._sampleRequests[self._requestIndex]
	-- print ("step 1")
	if not request then
		print ("if not request then")
		self:stop(true)
		return
	end
	-- print ("step 2")
	if not self:send(request.buffer) then
		print ("if not self:send(request.buffer) then")
		self:stop(false)
		return
	end
	-- dump(request)
	-- print ("step 3")
	-- local result = self:_response()
	-- if not result then
	-- 	print ("if not result then", debug.traceback())
	-- 	self:stop(false)
	-- 	return
	-- end
	-- print ("step 4")
	self._requestIndex = self._requestIndex + 1
	local nextRequest = self._sampleRequests[self._requestIndex]
	if not nextRequest then
		-- print ("if not nextRequest then")
		self:stop(true)
		return
	end
	if nextRequest.delay < 0 then
		print ("if nextRequest.delay < 0 then")
		self:stop(true)
		return
	end
	skynet.timeout(nextRequest.delay / 10, function() self:_sendSampleRequest(nextRequest) end)
end

return TestClient