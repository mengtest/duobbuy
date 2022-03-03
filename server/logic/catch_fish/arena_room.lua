local skynet = require("skynet")
local Room = require("catch_fish.room")
local dbHelp = require("common.db_help")
local resOp = require("common.res_operate")
local context = require("common.context")

local arenaConf = require("config.arena_config")

local ArenaRoom = class("ArenaRoom", Room)

local LogConst = require("game.log_const")
local CatchFishConst = require("catch_fish.catch_fish_const")
local PlayerState = CatchFishConst.PlayerState
local RoleConst = require("role.role_const")

local WAIT_TIME_LEN = 5	--等待倒计时长
local ARENA_TIME_LEN = 2 * 60 --比赛时长

function ArenaRoom:ctor(params)
	ArenaRoom.super.ctor(self, params)
	self._arena = params.arena

	--获取配置
	for _, item in ipairs(arenaConf) do
		if item.type == self._arena.type and item.level == self._arena.level then
			self._conf = item
			break
		end
	end

	self._minGunLevel = self._conf.minGunLevel
	self._endTime = self:_getNow() + ARENA_TIME_LEN + WAIT_TIME_LEN

	for roleId, player in pairs(self._arena.players) do
		local playerInfo = {}
		playerInfo.roleId = roleId
		playerInfo.nickname = player.nickname
		playerInfo.avatar = player.avatar
		playerInfo.gunType = 1
		playerInfo.gunLevel = self._minGunLevel
		playerInfo.gold = self._conf.bullet
		playerInfo.score = 0
		playerInfo.state = PlayerState.OFFLINE
		playerInfo.bullets = {}
		playerInfo.maxBulletId = 0
		playerInfo.costGold = 0
		playerInfo.totalCostGold = 0
		playerInfo.pos = player.pos
		playerInfo.winRate = player.winRate
		self._positions[player.pos] = true
		self._players[roleId] = playerInfo
	end
end

function ArenaRoom:getRoomInfo()
	local info = ArenaRoom.super.getRoomInfo(self)
	info.minGunLevel = self._minGunLevel
	info.type = self._arena.type
	info.level = self._arena.level
	info.endTime = self._endTime * 1000

	return info
end

function ArenaRoom:getArenaType()
	return self._arena.type
end

function ArenaRoom:getArenaLevel()
	return self._arena.level
end

function ArenaRoom:getPlayers()
	return self._players
end

function ArenaRoom:canEnter(roleId)
	local playerInfo = self._players[roleId]
	if playerInfo and playerInfo.state ~= PlayerState.GIVE_UP then
		return true
	end
end

function ArenaRoom:isOver()
	return self._isOver
end

function ArenaRoom:update(dt)
	ArenaRoom.super.update(self, dt)

	if self._isOver then
		return
	end
	
	if self:_getNow() >= self._endTime then
		--时间到了，比赛结束
		print("timeout")
		self:onOver()
		return
	end

	local count = 0
	for _, playerInfo in pairs(self._players) do
		if playerInfo.gold < self._minGunLevel 
			or playerInfo.state == PlayerState.GIVE_UP then
			count = count + 1
		end
	end

	if count == CatchFishConst.ROOM_PLAYER_COUNT then
		print("over")
		self:onOver()
		return
	end
end

function ArenaRoom:fire(fireInfo, cost)
	local now = self:_getNow()
	if self._endTime - now > ARENA_TIME_LEN then
		return CatchFishError.notStart
	elseif self._endTime <= now then
		return CatchFishError.arenaIsOver
	end

	local playerInfo  = self._players[fireInfo.roleId]
	if playerInfo.gunLevel < self._minGunLevel then
		return CatchFishError.gunLevelTooLow
	end
	if playerInfo.gold < cost then
		return CatchFishError.bulletNotEnough
	end
	playerInfo.gold = playerInfo.gold - cost
	ArenaRoom.super.fire(self, fireInfo, cost)

	self:_cast(M_CatchFish.handleArenaGoldUpdate, {roleId = fireInfo.roleId, gold = playerInfo.gold})
	return SystemError.success
end

function ArenaRoom:hit(hitInfo)
	if self._isOver then
		return CatchFishError.arenaIsOver
	end

	local playerInfo = self._players[hitInfo.roleId]
	if not playerInfo then
		return SystemError.argument
	end
	
	hitInfo.pumpRatio = 0
	local _, catchFishes = self:_doHit(playerInfo, hitInfo)
	local score = self:_doDropGold(hitInfo, catchFishes)

	playerInfo.score = playerInfo.score + score

	return SystemError.success, {0, 0, 0}
end

function ArenaRoom:updateGun(gunInfo)
	local playerInfo = self._players[gunInfo.roleId]
	playerInfo.gunLevel = gunInfo.gunLevel
	gunInfo.gunType = playerInfo.gunType
	self:_cast(M_CatchFish.handleUpdateGun, gunInfo)
	return SystemError.success
end

function ArenaRoom:addPlayer(info)
	local playerInfo = self._players[info.roleId]
	if playerInfo then
		playerInfo.state = PlayerState.NORMAL
		self:_cast(M_CatchFish.handlePlayerStateUpdate
			, {roleId = info.roleId, state = PlayerState.NORMAL})
	end
end

function ArenaRoom:removePlayer(roleId)
end

function ArenaRoom:updateGold()
end

function ArenaRoom:updateNotFishGold()
end

function ArenaRoom:updateVip()
end

function ArenaRoom:isEmpty()
	return false
end

function ArenaRoom:leave(roleId)
	local playerInfo = self._players[roleId]
	if playerInfo then
		playerInfo.state = PlayerState.OFFLINE
		self:_cast(M_CatchFish.handlePlayerStateUpdate, {roleId = roleId, state = PlayerState.OFFLINE}, roleId)
	end
end

function ArenaRoom:giveUp(roleId)
	local playerInfo = self._players[roleId]
	if playerInfo and playerInfo.state ~= PlayerState.GIVE_UP then
		playerInfo.state = PlayerState.GIVE_UP
		self:_cast(M_CatchFish.handlePlayerStateUpdate, {roleId = roleId, state = PlayerState.GIVE_UP}, roleId)
		return SystemError.success
	end
	return SystemError.illegalOperation
end

function ArenaRoom:onBegin()
	context.castS2C(nil, M_CatchFish.handleArenaBegin, self:getRoomId())
	-- self:_cast(M_CatchFish.handleArenaBegin, self:getRoomId(), nil, PlayerState.OFFLINE)
end

function ArenaRoom:onOver()
	self._isOver = true

	local players = {}
	for _, playerInfo in pairs(self._players) do
		playerInfo.rand = math.rand()
		players[#players + 1] = playerInfo
	end
	table.sort(players, function(p1, p2)
			if p1.score == p2.score then
				if p1.rand == p2.rand then
					return p1.roleId > p2.roleId
				end
				return p1.rand > p2.rand
			end
			return p1.score > p2.score
		end)
	
	--结算
	local result = {roomId = self:getRoomId(), items = {}}
	for rank, player in ipairs(players) do
		local award = self._conf.award[rank]
		if award then
			skynet.timeout(0, function() resOp.send(player.roleId, award.goodsId, award.amount, LogConst.betWin) end)
		end

		local point = self._conf.points[rank]
		if point then
			context.sendS2S(SERVICE.RANK, "addArenaScore", player.roleId, point, player.nickname)
		end

		local item = {roleId = player.roleId, nickname = player.nickname
									, rank = rank, score = player.score
									, goodsId = award and award.goodsId or 0
									, award = award and award.amount or 0
									, point = point or 0}
		result.items[#result.items + 1] = item
	end
	self:_cast(M_CatchFish.handleArenaOver, result, nil, PlayerState.NORMAL)

	result.type = self._arena.type
	result.level = self._arena.level
	dbHelp.send("catchFish.addArenaResult", result)

	local amount = self._conf.bet.amount * CatchFishConst.ROOM_PLAYER_COUNT
	for _, item in pairs(self._conf.award) do
		amount = amount - item.amount
	end
	dbHelp.send("catchFish.addArenaIncome", {type = self._arena.type, level = self._arena.level
		, goodsId = self._conf.bet.goodsId, amount = amount})

	--发送跑马灯
	local award = self._conf.award[1]
	local id
	if award.goodsId == RoleConst.GOLD_ID then
		id = 8
	else
		id = 9
	end
	context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = id, words = {players[1].nickname, award.amount}})
end

function ArenaRoom:_checkCatch(playerInfo, fish, bullet, awardPoolAddition, extraRatio)
	if fish:isDead() then
		return false
	end

	local ratio = 1 / fish:getGoldDrop() * (1.25 - playerInfo.winRate)
	return math.rand() <= ratio
end

function ArenaRoom:_checkSendMarquee()
end

function ArenaRoom:_getPlayerInfo(info)
	local playerInfo = ArenaRoom.super._getPlayerInfo(self, info)
	playerInfo.score = info.score
	playerInfo.state = info.state
	return playerInfo
end

function ArenaRoom:_cast(proto, data, exclude, state)
	state = state or PlayerState.NORMAL
	local roleIds = {}
	for _, playerInfo in pairs(self._players) do
		if playerInfo.state == state and playerInfo.roleId ~= exclude then
			roleIds[#roleIds + 1] = playerInfo.roleId
		end
	end

	context.sendMultiS2C(roleIds, proto, data)
end

return ArenaRoom