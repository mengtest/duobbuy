local skynet = require("skynet")
local netpack = require("netpack")
local socket = require("socket")
local httpc = require("http.httpc")
local logger = require("log")
require("functions")
local json = require("json")
local protoMap = require("proto_map")
local protobuf = require("protobuf")

local FishObject = require("catch_fish.fish_object")
local Bullet = require("catch_fish.bullet")

local GunConf = require("config.gun")

local MESSAGE_HEADER_LENGTH = 4
local REQUEST_MESSAGE_HEADER_LENGTH = 6
local EVENT_MESSAGE_HEADER_LENGTH = 4
local HEARTBEAT_PROTO_ID = 0x0103

local EC_SUCCESS                = 0
local EC_USER_NOT_EXIST         = 1003
local EC_HTTP_METHOD_ERROR      = 1000
local EC_PARAM_INVILD           = 1001
local EC_NOT_SUPPORT_API_METHOD = 1002
local EC_PWD_IS_ERROR           = 1004

local display = {x = 0, y = 0, width = 1024, height = 576}
local GUN_X = 300
local GUN_POS = {
	{GUN_X, 0}, 
	{1024 - GUN_X, 0}, 
	{GUN_X, -576}, 
	{1024 - GUN_X, -576}
}

local TestClient = class("TestClient")

function TestClient:ctor(protos, completedCallback)
	self._requestId = 0
	self._msgHeader = {length = 0, protoId = 0}
	self._maxMsgSize = 2 ^ 16
	self._protosById = protos
	self._latestResponseTime = 0
	self._completedCallback = completedCallback
	self._tryLoginNum = 0
end

function TestClient:init(loginHost, loginUrl, serverId, account, password, serverHost, serverPort)
	self._loginHost = loginHost
	self._loginUrl = loginUrl
	self._serverId = serverId
	self._account = account
	self._password = password
	self._serverHost = serverHost
	self._serverPort = serverPort
	assert(self._account ~= nil)
end

function TestClient:reset()
	-- print("reset account:", self._account, " Status:", self:getStatus())
	self._serverInfo = nil
	-- self._fd = nil
	if self._fd then
		socket.close_fd(self._fd)
		self._fd = nil
	end
	self._roleId = nil
	self._roomInfo = nil
	self._playerInfo = nil
end

function TestClient:getStatus()
	-- if not self._serverInfo then
	-- 	return "验证账号"
	-- end

	if not self._fd then
		return "创建 socket"
	end

	if not self._roleId then
		return "登陆中"
	end

	if not self._playerInfo then
		return "进入房间中"
	end

	return "捕鱼中"
end

function TestClient:auth_account()
	--验证账号
	local postData = "method=login&" .. "accountName=" .. self._account .. "&pwd=123456"-- .. password
	local header = {["Content-Type"] = "application/x-www-form-urlencoded"}
	local statuscode, data = httpc.request("POST", self._loginHost, self._loginUrl, nil, header, postData)
	if statuscode ~= 200 or not data then
		return false
	end

	local authInfo = json.decode(data)

	if authInfo.errorCode == EC_USER_NOT_EXIST then  --创建账号
		local postData = "method=register&" .. "accountName=" .. self._account .. "&pwd=123456"-- .. password
		local header = {["Content-Type"] = "application/x-www-form-urlencoded"}
		local statuscode, data = httpc.request("POST", self._loginHost, self._loginUrl, nil, header, postData)
		if statuscode ~= 200 or not data then
			dump(data)
			return false
		end
		authInfo = json.decode(data)
		if authInfo.errorCode ~= EC_SUCCESS then
			return false
		end
	elseif authInfo.errorCode ~= EC_SUCCESS then
		dump(data)
		return false
    end
   
    if #authInfo.data.serverList == 0 then
		return false
    end
	
	for _, server in pairs(authInfo.data.serverList) do
		if tonumber(server.sid) == self._serverId then
			self._serverInfo = server
			self._authInfo = authInfo
			return
		end
	end
end


function TestClient:onLogin(ec, data)
	-- print(string.format("%#x",ec))
	if ec ~= SystemError.success then return end
	if not self._roleId then
		self._roleId = data.roleId or 0
	end
end

function TestClient:onCreateRole(ec, data)
	if ec ~= SystemError.success then 
		-- print(string.format("%#x",ec))
		return 
	end
	self:reset()
end

function TestClient:getAccount()
	return self._account
end


function TestClient:stop(completed)
	if self._fd then
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

function TestClient:update(dt)
	for objectId, fish in pairs(self._fishes) do
		fish:update(dt)
		if fish:isMovedOut() then
			self._fishes[objectId] = nil
		end
	end

	for _, bullet in pairs(self._bullets) do
		bullet:update(dt)
	end

	self:_checkCollision()

	self:_checkFire()

	if not self._isRequest then
		self:_response()
	end
end

----------------------------------------------------------------------------
function TestClient:request(proto, data)
	if not self:isConnected() then
		return
	end

	if self._isRequest then
		return
	end
	
	local ret, requestId = self:sendData(proto, data)
	if not ret then
		return
	end

	self._isRequest = true
	local result = self:_response()
	self._isRequest = false
	return result
end

function TestClient:sendData(proto, data)
	local buffer = nil
	if proto.request then
		if proto.request == "int8" then
			-- buffer = "1234567"
			protobuf.encode_int8(buffer, REQUEST_MESSAGE_HEADER_LENGTH, data)
		elseif proto.request == "int16" then
			-- buffer = "12345678"
			protobuf.encode_int16(buffer, REQUEST_MESSAGE_HEADER_LENGTH, data)
		elseif proto.request == "int32" then
			-- buffer = "1234567890"
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

	local ok = socket.write(self._fd, buffer)
	if not ok then
		return false
	end
	return true, self._requestId
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

	-- local protoId = string.format("%#x",proto.id)
	local protoId = proto.id
	if protoId == M_Auth.login.id then
		self:onLogin(ec, data)
	elseif protoId == M_Auth.createRole.id then
		self:onCreateRole(ec, data)
	elseif protoId == M_CatchFish.enterRoom.id then
		self:_onEnterRoom(ec, data)
		self:heartbeat(10)
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
	return data
end

function TestClient:_onHBTimeout()
	if not self:isConnected() then
		return
	end
	
	local now = os.time()
	if now - self._latestResponseTime > self._hbInterval then
		self:request(M_Auth.heartbeat)
	end
	
	skynet.timeout(self._hbInterval, handler(self, self._onHBTimeout))
end

function TestClient:start()
	skynet.timeout(100, handler(self, self.start))

	if self._tryLoginNum > 10 then
		return
	end

	-- 验证账号
	-- if not self._serverInfo then
	-- 	local ret, num = self:auth_account()
	-- 	-- print("num:",num)
	-- 	return
	-- end
	if not self._fd then
		self._tryLoginNum = self._tryLoginNum + 1
		-- print("self._fd = socket.open(119.23.19.71, 5901)")
		-- print("serverHost:"..self._serverHost.." serverPort:"..self._serverPort)
		self._fd = socket.open(self._serverHost, self._serverPort)
		return
	end

	if not self._roleId then
		self._tryLoginNum = self._tryLoginNum + 1
		local loginInfo = {
			uid = self._account,
			token = "123",--self._authInfo.data.token,
			signTime = "123",--self._authInfo.data.time,
			-- serverId = "1",--self._serverInfo.sid
		}
		self:request(M_Auth.login, loginInfo)	
		return
	end

	if self._roleId == 0 then
		self:request(M_Auth.createRole, {nickname = self._account, avatar = math.rand(1, 5), pid = 0, channelId = 0, imei = self._account})
		return
	end

	--进入普通捕鱼场
	if not self._playerInfo then
		self._tryLoginNum = self._tryLoginNum + 1
		self:request(M_CatchFish.enterRoom, nil)
		return
	end
end

function TestClient:catchFish()
	skynet.timeout(20, handler(self, self.catchFish))

	if not self._playerInfo then
		return
	end

	if not self.bulletId then self.bulletId = 0 end
	-- 开炮
	local FireInfo = {
		roleId = self._playerInfo.roleId,
		fireAngle = self._playerInfo.pos,
		fireTime = os.time(),
	}
	if self._playerInfo.pos == 4 then
		FireInfo.fireAngle = 3
	end
	self:sendData(M_CatchFish.fire, FireInfo)

	-- 命中
	local HitInfo = {
		roleId = self._playerInfo.roleId,
		hits = {},
	}
	local fish = self:_getAutoFireFish()
	if fish then
		self.bulletId = self.bulletId + 1
		local hit = {bulletId = self.bulletId, fishId = fish._objectId}
		table.insert(HitInfo.hits, hit)
	end
	if not table.empty(HitInfo.hits) then
		self:sendData(M_CatchFish.hit, HitInfo)
	end
end

function TestClient:_response()
	local buffer = self:read(MESSAGE_HEADER_LENGTH)
	if not buffer then
		return
	end
	local header = self:_decodeHeader(buffer)
	if header.length > self._maxMsgSize then
		return
	end
	local proto = self._protosById[header.protoId]
	if not proto then
		return
	end

	local msgLen = header.length + 2
	if msgLen - MESSAGE_HEADER_LENGTH == 0 then
		if proto.type == PROTO_TYPE.S2C then
			local result = self:_decodeS2C(proto, buffer, msgLen)
			self:_dispatchS2C(proto.id, result)
			self:_response()
		end
		return
	end

	local bodybuffer = self:read(msgLen - MESSAGE_HEADER_LENGTH)
	if not bodybuffer then
		return
	end

	buffer = buffer .. bodybuffer
	
	if proto.type == PROTO_TYPE.C2S then
		return self:_decodeC2S(proto, buffer, msgLen)
	elseif proto.type == PROTO_TYPE.S2C then
		local result = self:_decodeS2C(proto, buffer, msgLen)
		self:_dispatchS2C(proto.id, result)
		self:_response()
		return
	else
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

-----------------------------------------------------------------------
function TestClient:_getNowTime()
	return (skynet.time() - self._diffTimeToServer) - self._roomInfo.createTime
end

function TestClient:_dispatchS2C(protoId, result)
	if not self._roomInfo then
		return
	end
	if protoId == M_CatchFish.handlePlayerGoldUpdate.id then
		if self._playerInfo and result.roleId == self._playerInfo.roleId then
			self._playerInfo.gold = result.gold
		end
	elseif protoId == M_CatchFish.handleFishBorn.id then
		self:_addFishes(result.fishes)
	elseif protoId == M_CatchFish.handleFishStrikes.id then
		self._fishes = {}
	elseif protoId == M_CatchFish.handleDrop.id then
		for _, drop in ipairs(result.drops) do
			if self._fishes then
				self._fishes[drop.fishId] = nil
			end
		end
	end
end

function TestClient:_getRoleInfo()
	if self._roleInfo then
		return true
	end
	local result = self:request(M_Role.getRoleInfo, nil)
	if not result or result.errorCode ~= SystemError.success then
		return false
	end
	self._roleInfo = result.data
	return true
end


function TestClient:_onEnterRoom(ec, data)
	if ec ~= SystemError.success then return end

	self._roomInfo = data

	for _, playerInfo in pairs(self._roomInfo.players) do
		if playerInfo.roleId == self._roleId then 
			self._playerInfo = playerInfo
			-- print("enter room. "..self._playerInfo.nickname)
			break
		end
	end
	self._diffTimeToServer = skynet.time() - self._roomInfo.curTime
	self._prevFireTime = 0

	--初始化捕鱼场信息
	self._fishes = {}
	self._bullets = {}
	self._maxBulletId = 0
	self:_addFishes(self._roomInfo.fishes)
end

function TestClient:_addFishes(infos)
	local now = self:_getNowTime()
	for _, fishInfo in pairs(infos) do
		local fish = FishObject.new({
				objectId = fishInfo.objectId,
				type = fishInfo.type,
				pathId = fishInfo.pathId,
				bornX = fishInfo.bornX,
				bornY = fishInfo.bornY,
				rotation = fishInfo.rotation,
				aliveTime = 0,
				children = nil,
			})
		self._fishes[fishInfo.objectId] = fish
		fish:update(now - fishInfo.bornTime / 100)
	end
end

function TestClient:_addBullet(bulletInfo)
	local bullet = Bullet.new({
			bulletId = bulletInfo.bulletId,
			type = bulletInfo.type,
			level = bulletInfo.level,
			fireAngle = bulletInfo.fireAngle,
			curX = bulletInfo.curX,
			curY = bulletInfo.curY,
			fireTime = 0,
			aimFish = bulletInfo.fireFish,
		})
	
	self._bullets[bulletInfo.bulletId] = bullet
end

function TestClient:_canFire()
	local conf = GunConf[self._playerInfo.gunType]
	return self._playerInfo.gold >= conf.cost * self._playerInfo.gunLevel
end

function TestClient:_getFireInterval()
	local conf = GunConf[self._playerInfo.gunType]
	return conf.fireInterval / 1000
end

function TestClient:_getFirePos(fish)
	return fish:getX(), fish:getY()
end

function TestClient:_checkFire()
	local now = self:_getNowTime()
	if now - self._prevFireTime < self._model:getFireInterval() then
		return
	end

	local x, y
	local fish = self:_getAutoFireFish()
	if fish then
		x, y = self:_getFirePos(fish)
	else
		return
	end

	self:_fire(x, y)
end

function TestClient:_getAutoFireFish()
	local fishes = {}
	for _, fish in pairs(self._fishes) do
		if fish:isBorned() and not fish:isDead() then
			local x, y = fish:getX(), fish:getY()
			if x > 0 and x < display.width and y > 0 and y < display.height then
				fishes[#fishes + 1] = fish
			end
		end
	end

	table.sort(fishes, function(fish1, fish2)
			if fish1:getAutoFirePrority() == fish2:getAutoFirePrority() then
				return fish1:getObjectId() < fish2:getObjectId()
			end
			return fish1:getAutoFirePrority() > fish2:getAutoFirePrority()
		end)
	return fishes[1]
end

function TestClient:_getFireAngle(x, y)
	local gunPos = GUN_POS[self._playerInfo.pos]
	local dx = x - gunPos[1]
	local dy = y - gunPos[2]
	local angle = math.atan2(-dy, dx)
	return angle
end

function TestClient:_fire(x, y)
	local fireAngle = self:_getFireAngle(x, y)
	if (fireAngle >= 0 and fireAngle <= math.pi)
		or (fireAngle >= math.pi and fireAngle <= 2 * math.pi)  then
		local fireInfo = {
			fireAngle = fireAngle,
			fireTime = self:_getNowTime(),
		}
		local result = self:request(M_CatchFish.fire, fireInfo)
		if result.errorCode ~= SystemError.success then
			return false
		end
		self._prevFireTime = self:_getNowTime()

		self._maxBulletId = self._maxBulletId + 1
		self:_addBullet({
				bulletId = self._maxBulletId,
				type = playerInfo.gunType,
				level = playerInfo.gunLevel,
				fireTime = fireInfo.fireTime,
				fireAngle = fireInfo.fireAngle,
				curX = startX,
				curY = startY,
			})
	end
	return true
end

function TestClient:_hit(hits)
	local result = self:request(M_CatchFish.hit, {hits = hits})
	if result.errorCode ~= SystemError.success then
		return false
	end
end

function TestClient:_checkCollision()
	local fishes = {}
	for _, fish in pairs(self._fishes) do
		if fish:isBorned() then
			fishes[#fishes + 1] = fish
		end
	end

	table.sort(fishes, function(fish1, fish2)
			if fish1:getZOrder() == fish2:getZOrder() then
				return fish1:getObjectId() < fish2:getObjectId()
			end
			return fish1:getZOrder() < fish2:getZOrder()
		end)

	local hits = {}
	for bulletId, bullet in pairs(self._bullets) do
		local bulletX, bulletY = bullet:getX(), bullet:getY()
		local fish = bullet:getAimFish()
		if fish then
			if fish:checkCollison(bulletX, bulletY) then
				hits[#hits + 1] = {bulletId = bulletId, fishId = fish:getObjectId()}
				self._bullets[bulletId] = nil
			end
		else
			for _, fish in ipairs(fishes) do
				if fish:checkCollison(bulletX, bulletY) then
					hits[#hits + 1] = {bulletId = bulletId, fishId = fish:getObjectId()}
					break
				end
			end
		end
	end

	if #hits > 0 then
		self:_hit(hits)
	end
end


return TestClient