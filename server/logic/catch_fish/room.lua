local table = table
local math = math
local skynet = require("skynet")
local logger = require("log")
local context = require("common.context")

local Bullet = require("catch_fish.bullet")
local FishObject = require("catch_fish.fish_object")
local BossObject = require("catch_fish.boss_object")

local FishConf = require("config.fish")
local FishPathConf = require("config.fish_path")
local FishPathGroupConf = require("config.fish_path_group")
local FishGroupConf = require("config.fish_group")
local FishGroupTypeConf = require("config.fish_group_type")
local FishRefresh = require("config.fish_refresh")
local FishStrikesRefresh = require("config.fish_strikes_refresh")
local GunLevelConf = require("config.gun_level")
local PoolConf = require("config.pool")
local PersonalBenefit = require("config.personal_benefit")
local ProtectAdditionConf = require("config.protect_rate_addition")
local RobotChargeConf = require("config.robot_charge")

local CatchFishConst = require("catch_fish.catch_fish_const")
local FishType = CatchFishConst.FishType

-- 机器人相关
local GameConfig = require("config.game_config")
local FIRE_INTERVAL = GameConfig.fireInterval

local EXPECTED_GET_TREASURE_RATIO = 6000	--预期消耗金币获得多夺宝卡比率
local FISH_STRIKES_BORN_INTERVAL = 60 * 10
local MAX_INCOME_MULTI = 4		--玩家最大收益倍数
local FREEZE_TIME_LEN = 5    --冰冻时长
local MISS_RESET_TIME_LEN = 2
local FISH_STRIKES_WAVE_COUNT = 1
local FISH_STRIKES_ONE_WAVE_TIME = 6
local LOCAL_BOMB_RANGE = 100
local POS_COUNT = 4
local BULLET_SPEED = 700
local MAX_BULLET_ALIVE_TIME = 100
local MIN_BORN_INTERVAL = 4
local GUN_X = 310
local GUN_POS = {
	{GUN_X, 0}, 
	{1024 - GUN_X, 0}, 
	{1024 - GUN_X, 576}, 
	{GUN_X, 576}
}

-- local GET_TREASURE_VALUES = {
-- 	{50000, 0.20},
-- 	{60000, 0.75},
-- 	{65000, 1},
-- }

-- 2017.4.5 修改
local GET_TREASURE_VALUES = {
	{55000, 0.25},
	{60000, 0.65},
	{65000, 1},
}

local GOT_TREASURE_GOLD_FOR_NEWBIE = 10000 --新手玩家获得1张夺宝卡的金币消耗
local HIT_EXTRA_RATIO = 0.3	--极光炮击中其他鱼的概率
local CHENFG_JIE_GUN_RANGE = 65  -- 爆裂惩戒命中范围

-- 机器人捕鱼相关
local DisPlay = {
	height = 576,
	width = 1024,
}

local Room = class("Room")

function Room:ctor(params)
	assert(params.roomId)
	assert(params.sendMarquee)
	assert(params.protect)
	assert(params.maxGoldOfFreePlayer)

	self._roomId = params.roomId
	self._sendMarquee = params.sendMarquee
	self._protect = params.protect
	self._maxGoldOfFreePlayer = params.maxGoldOfFreePlayer

	self._createTime = skynet.time()
	self._players = {}
	self._positions = {}
	self._fishes = {}
	self._nextObjectId = 1
	self._nextBulletId = 1
	self._timerHandle = 0
	self._timers = {}
	self._bornTimers = {}

	self:_scheduleBornFish()

	self:_updateTimers(MIN_BORN_INTERVAL)
end

function Room:destroy()
	-- logger.Pf("Room:destroy() self._roomId:"..self._roomId.." fish num:"..table.nums(self._fishes))
	for k in pairs(self._players or {}) do
		self._players[k] = nil
	end

	for k in pairs(self._positions) do
		self._positions[k] = nil
	end

	for k, fish in pairs(self._fishes) do
		fish:destroy()
		self._fishes[k] = nil
	end

	for k,timer in pairs(self._timers) do
		if timer.callback then
			timer.callback = nil
		end
		self._timers[k] = nil
	end

	for k,timer in pairs(self._bornTimers) do
		self._bornTimers[k] = nil
	end

	self._roomId = nil
	self._sendMarquee = nil
	self._protect = nil
	self._maxGoldOfFreePlayer = nil

	self._createTime = nil
	self._players = nil
	self._positions = nil
	self._fishes = nil
	self._nextObjectId = nil
	self._nextBulletId = nil
	self._timerHandle = nil
	self._timers = nil
	self._bornTimers = nil
end

function Room:isVip()
	return false
end

function Room:isProtect()
	return self._protect
end

function Room:setProtect(value)
	self._protect = value
end

function Room:isOver()
	return false
end

function Room:addPlayer(playerInfo)
	assert(not self._players[playerInfo.roleId], string.format("player [%d] is in room", playerInfo.roleId))
	-- 记录机器人最后一次进入房间的时间
	if playerInfo.isRobot then
		self._robotLastJoinTimeAt = skynet.time()
		self._nextRobotJoinTimeAt = skynet.time() + math.floor(math.rand(5,15))
		assert(playerInfo.exitAt)
	end

	for i = 1, POS_COUNT do
		if not self._positions[i] then
			self._positions[i] = true
			self._players[playerInfo.roleId] = playerInfo
			playerInfo.pos = i
			playerInfo.bullets = {}
			playerInfo.maxBulletId = 0
			-- playerInfo.costGold = 0			-- 本房间消耗的金币
			playerInfo.valuePool = 0
			playerInfo.latestHitFish = 0
			playerInfo.hitTimes = 0
			playerInfo.leftAddTimes = 0

			--发送玩家加入事件
			local info = self:_getPlayerInfo(playerInfo)
			self:_cast(M_CatchFish.handlePlayerEnter, info, playerInfo.roleId)
			return
		end
	end
end

function Room:removePlayer(roleId)
	local playerInfo = self._players[roleId]
	
	-- 记录机器人最后一次进入房间的时间
	if playerInfo.isRobot then
		self._nextRobotJoinTimeAt = skynet.time() + math.floor(math.rand(5,15))
	end

	for k,bullet in ipairs(playerInfo.bullets) do
		bullet:destroy()
		playerInfo.bullets[k] = nil
	end

	self._players[roleId] = nil
	if not self._players then self._players = {} end
	self._positions[playerInfo.pos] = nil
	if not self._positions then self._positions = {} end

	self:_cast(M_CatchFish.handlePlayerLeave, roleId, roleId)
end

function Room:hasEmptyPos()
	return table.nums(self._players or {}) < POS_COUNT
end

function Room:isEmpty()
	return table.empty(self._players)
end

function Room:getRobotNum()
	local robotNum = 0
	for _,playerInfo in pairs(self._players or {}) do
		if playerInfo.isRobot then
			robotNum = robotNum + 1
		end
	end
	return robotNum
end

function Room:getPlayerNum()
	local playerNum = 0
	for _,playerInfo in pairs(self._players or {} or {}) do
		if not playerInfo.isRobot then
			playerNum = playerNum + 1
		end
	end
	return playerNum
end

function Room:getRoomId()
	return self._roomId
end

function Room:getRoomInfo()
	local roomInfo = {}
	roomInfo.roomId = self._roomId
	roomInfo.createTime = self._createTime
	roomInfo.curTime = skynet.time()

	if self._isFrozen then
		roomInfo.freezeTime = self._freezeTime * 100
	end

	local players = {}
	for _, playerInfo in pairs(self._players or {}) do
		players[#players + 1] = self:_getPlayerInfo(playerInfo)
	end
	roomInfo.players = players

	local fishes = {}
	for _, fish in pairs(self._fishes) do
		fishes[#fishes + 1] = fish:getInfo()
	end
	roomInfo.fishes = fishes

	-- dump(fishes)

	return roomInfo
end

function Room:fire(fireInfo, cost)
	local playerInfo = self._players[fireInfo.roleId]
	playerInfo.costGold = playerInfo.costGold + cost
	playerInfo.totalCostGold = playerInfo.totalCostGold + cost
	
	local bullet = Bullet.new({
			type = playerInfo.gunType,
			level = playerInfo.gunLevel,
			fireAngle = fireInfo.fireAngle,
			fireTime = fireInfo.fireTime  or math.floor(skynet.time() - self._createTime),
			aimFish = playerInfo.aimObjectId,
		})
	playerInfo.maxBulletId = playerInfo.maxBulletId + 1
	playerInfo.bullets[playerInfo.maxBulletId] = bullet
	fireInfo.bulletId = playerInfo.maxBulletId

	local disabledBullet
	if table.nums(playerInfo.bullets) > 50 then
		for bulletId,_ in pairs(playerInfo.bullets) do
			if not disabledBullet then
				disabledBullet = bulletId
			end
			if bulletId < disabledBullet then
				disabledBullet = bulletId
			end
		end
	end
	if disabledBullet then
		local obj = playerInfo.bullets[disabledBullet]
		if obj then
			obj:destroy()
		end
		playerInfo.bullets[disabledBullet] = nil
	end
	
	self:_cast(M_CatchFish.handleFire, fireInfo, fireInfo.roleId)
	
	return SystemError.success, playerInfo.costGold
end

function Room:aim(aimInfo)
	--检查对象是否存在
	if not self._fishes[aimInfo.objectId] then
		return SystemError.success
	end
	local playerInfo = self._players[aimInfo.roleId]
	if not playerInfo then
		return SystemError.argument
	end
	playerInfo.aimObjectId = aimInfo.objectId
	self:_cast(M_CatchFish.handleAim, aimInfo, aimInfo.roleId)
	return SystemError.success
end

function Room:stopAim(roleId)
	local playerInfo = self._players[roleId]
	if not playerInfo then
		return SystemError.argument
	end
	playerInfo.aimObjectId = nil
	self:_cast(M_CatchFish.handleStopAim, roleId, roleId)
	return SystemError.success
end

function Room:getAutoFish(autoFish)
	if table.empty(self._fishes) then 
		return 
	end 

	if not autoFish or autoFish == 0 then 
		local fishNum = table.nums(self._fishes)
		local luckyNum = math.rand(1, fishNum)
		for _,fish in pairs(self._fishes) do
			luckyNum = luckyNum - 1
			if luckyNum <= 0 and not fish:isDead() then 
				local x,y = fish:getX(),fish:getY()
				if x > 0 and x < DisPlay.width and y > 0 and y < DisPlay.height then
					return fish:getObjectId()
				end
			end 
		end
		return
	end

	local target
	local maxPrority = 0
	for _,fish in pairs(self._fishes) do
		if not fish:isDead() then
			local x,y = fish:getX(),fish:getY()
			if x > 0 and x < DisPlay.width and y > 0 and y < DisPlay.height then
				if fish:getAutoFirePrority() > maxPrority then 
					maxPrority = fish:getAutoFirePrority()
					target = fish:getObjectId()
				elseif fish:getAutoFirePrority() == maxPrority and math.rand(1,100) < 50 then 
					target = fish:getObjectId()
				end
			end
		end
	end
	return target
end

function Room:getFireAngle(playerInfo)
	local autoFish = playerInfo.autoFish
	if not autoFish then
		autoFish = self:getAutoFish(playerInfo.autoFishType)
		playerInfo.autoFish= autoFish
	end
	if not autoFish then return end

	local fish = self._fishes[autoFish]	
	if not fish or fish:isDead() or 
		fish:getX() < 0 or fish:getX() > DisPlay.width or
		fish:getY() < 0 or fish:getY() > DisPlay.height then
		autoFish = self:getAutoFish()
		playerInfo.autoFish = autoFish
		return
	end

	local x,y = fish:getX(),fish:getY()
	y = DisPlay.height - y
	local gunPos = GUN_POS[playerInfo.pos]
	local dx = x - gunPos[1]
	local dy = y - gunPos[2]
	local angle = math.atan2(-dy, dx)
	if math.abs(math.abs(angle) - math.abs(math.pi)) < 0.5 then
		playerInfo.autoFish = nil
		return
	end

	if playerInfo.isAim and fish:getGoldDrop() > 200 and (not playerInfo.aimFish or playerInfo.aimObjectId ~= fish:getObjectId()) then 
		self:aim({roleId = playerInfo.roleId, objectId = fish:getObjectId()})
	end
	if playerInfo.aimObjectId and playerInfo.aimObjectId ~= fish:getObjectId() then 
		self:stopAim(playerInfo.roleId)
	end
	return angle
end

function Room:updateRobot()
	for roleId,playerInfo in pairs(self._players or {}) do
		if playerInfo.isRobot then
			if not playerInfo.leavingAt then
				self:robotFire(roleId)
			end
		end
	end
end

function Room:robotFire(roleId)
	-- __MONITOR("Room:robotFire")
	if self:getPlayerNum() == 0 and math.rand(100) % 5 < 1 then 
		return 
	end 
	local playerInfo = self._players[roleId]
	if not playerInfo or not playerInfo.isRobot then return end
	if playerInfo.leavingAt then return end

	-- 切换炮倍数
	playerInfo.changeGunTimes = (playerInfo.changeGunTimes or 0) - 1
	if playerInfo.changeGunTimes <= 0 and playerInfo.gunLevel ~= playerInfo.normalGunLevel then
		local levelList = {10,20,50,100,150,200,300,400,500,600,700,800,900,1000,2000,3000,4000,5000,10000}
		for i=1,#levelList do
			if playerInfo.gunLevel == levelList[i] then 
				if playerInfo.gunLevel < playerInfo.normalGunLevel then
					playerInfo.gunLevel = levelList[i + 1] or playerInfo.gunLevel
				elseif playerInfo.gunLevel > playerInfo.normalGunLevel then
					playerInfo.gunLevel = levelList[i - 1] or playerInfo.gunLevel
				end 
				self:updateGun({roleId = playerInfo.roleId, gunType = playerInfo.gunType, gunLevel = playerInfo.gunLevel})
				playerInfo.changeGunTimes = math.rand(2,3)
				if playerInfo.pauseTimes < 4 then 
					playerInfo.pauseTimes = 4
				end 
				break
			end 
		end
	end

	-- 机器人每在线随机3~5分钟时，随机+/-（1~5）档炮倍
	if not playerInfo.nextChangeGunTimes then 
		playerInfo.nextChangeGunTimes = math.rand(3 * 60, 5 * 60) / FIRE_INTERVAL
	end
	playerInfo.nextChangeGunTimes = playerInfo.nextChangeGunTimes - 1
	if playerInfo.nextChangeGunTimes <= 0 then 
		local levelList = {10,20,50,100,150,200,300,400,500,600,700,800,900,1000,2000,3000,4000,5000}
		local gunIndex = 10
		for i=1,#levelList do
			if levelList[i] == playerInfo.normalGunLevel then 
				gunIndex = i
				break
			end
		end

		-- 随机+/-（1~5）档炮倍
		local minLevel = math.max(0, gunIndex - 5)
		local maxLevel = math.min(#levelList, gunIndex + 5)
		gunIndex = math.rand(math.max(0, gunIndex - 5), math.min(#levelList, gunIndex + 5))
		playerInfo.normalGunLevel = levelList[gunIndex] or playerInfo.normalGunLevel
		playerInfo.nextChangeGunTimes = math.rand(3 * 60, 5 * 60) / FIRE_INTERVAL
	end

	-- 准备时间
	if playerInfo.pauseTimes > 0 then
		playerInfo.pauseTimes = playerInfo.pauseTimes - 1
		return
	end

	-- 充值金币
	if playerInfo.chargeNum then 
		self:updateGold(roleId, (playerInfo.gold + playerInfo.chargeNum), exclude)
		playerInfo.chargeNum = nil
		playerInfo.pauseTimes = 10
		return
	end

	-- 鱼的数量少于指定数量时不开炮
	if table.nums(self._fishes) < 10 then
		return
	end

	local cost = playerInfo.gunLevel
	-- 金币不足充值
	if playerInfo.gold < cost then
		playerInfo.pauseTimes = 50
		local RobotChargeVO = RobotChargeConf[playerInfo.gunLevel]
		if RobotChargeVO then 
			playerInfo.chargeNum = RobotChargeVO.gold[math.rand(100) % #RobotChargeVO.gold + 1]
		else 
			playerInfo.leavingAt = math.rand(5,10) + skynet.time()
		end 
		return
	end

	-- 达到退出条件
	if playerInfo.gold >= playerInfo.goldUpperLimit or playerInfo.gold <= playerInfo.goldLowerLimit then
		playerInfo.leavingAt = math.rand(5,10) + skynet.time()
		return
	end

	-- 获得捕鱼角度
	local angle = self:getFireAngle(playerInfo)
	if not angle then return end
	-- print("angle:"..angle)
	local fireTime = math.floor(skynet.time() - self._createTime)
	local fireInfo = {fireAngle = angle, fireTime = fireTime, roleId = roleId}
	self:fire(fireInfo, cost)
	self:updateGold(roleId, (playerInfo.gold - cost), exclude)
	playerInfo.treasureCost[2] = playerInfo.treasureCost[2] + cost

	playerInfo.fireNum = (playerInfo.fireNum or 0) + 1
	if playerInfo.pause then
		if playerInfo.fireNum > playerInfo.pause[1] then
			playerInfo.fireNum = 0
			playerInfo.pauseTimes = playerInfo.pause[2]
		end
	end
	-- __MONITOR("Room:robotFire", 1)
end

function Room:robotHit(hitInfo)
	-- __MONITOR("Room:robotHit")
	local roleId = hitInfo.roleId
	local playerInfo = self._players[roleId]
	if not playerInfo or not playerInfo.isRobot then 
		return SystemError.illegalOperation
	end

	local totalGold = 0
	
	local castHitInfo = {}
	castHitInfo.roleId = roleId
	castHitInfo.hits = {}

	local dropInfo = {}
	dropInfo.roleId = roleId
	dropInfo.drops = {}

	local DropTreasure

	for _,hitInfo in pairs(hitInfo.hits) do
		local bulletId = hitInfo.bulletId
		local bullet = playerInfo.bullets[bulletId]
		if not bullet then
			return SystemError.illegalOperation			
		end
		playerInfo.bullets[bulletId] = nil
		
		local fishId = hitInfo.fishId
		local fish = self._fishes[fishId]
		if not fish then
			return SystemError.illegalOperation			
		end

		function canHitFish(playerInfo, fish, fixRatio)
			local ratio = fish:getNormalRatio() * 1000000 * fixRatio
			-- 配置对机器人捕鱼概率的加成
			ratio = ratio * playerInfo.hitRatio / 10000
			-- print("ratio:"..ratio.." fixRatio:"..fixRatio)
			local ret = math.rand(1, 1000000) < ratio
			-- print("ret:"..tostring(ret).." fish:"..fish:getGoldDrop())
			return ret
		end

		local fixRatio = 1
		-- 极光魅影，特殊处理
		local extraFishes = {}
		if bullet:getType() == CatchFishConst.JI_GUANG_GUN and math.rand(0, 100) <= HIT_EXTRA_RATIO * 100 then
			local hitFishIds = self:getJiGuangGunExtraFishes()
			local num = table.nums(hitFishIds)
			if num == 0 then break end
			fixRatio = 1 / num
			for _, extraFishId in pairs(hitFishIds) do
				local extrafish = self._fishes[extraFishId]
				table.insert(extraFishes, extraFishId)
				if extrafish and not extrafish:isBoss() and canHitFish(playerInfo, extrafish, fixRatio) then
					local gold = self:_getDropGlod(extrafish, bullet)
					table.insert(dropInfo.drops, {crit = 1, fishId = extraFishId, gold = gold})
					totalGold = totalGold + gold
					self._fishes[extraFishId] = nil
				end
			end
		end
		
		if not table.empty(extraFishes) then
			fixRatio = 1 - HIT_EXTRA_RATIO
		end
		
		if canHitFish(playerInfo, fish, fixRatio) then
			local gold = self:_getDropGlod(fish, bullet)
			table.insert(dropInfo.drops, {crit = 1, fishId = fishId, gold = gold})
			totalGold = totalGold + gold
			self._fishes[fishId] = nil
		end
		
		table.insert(castHitInfo.hits, {bulletId = bulletId, fishId = fishId, extraFishes = extraFishes, bulletType = bullet:getType()})

		if playerInfo.treasureCost[2] > playerInfo.treasureCost[1] then
			playerInfo.treasureCost[2] = 0
			DropTreasure = {roleId = roleId, fishId = fishId, treasure = 1}
		end
	end
	-- print("totalGold:"..totalGold.." castHitInfo.hits:"..table.nums(castHitInfo.hits))
	if not table.empty(castHitInfo.hits) then
		self:_cast(M_CatchFish.handleHit, castHitInfo)
	end
	if not table.empty(dropInfo) then
		self:_cast(M_CatchFish.handleDrop, dropInfo)
		self:updateGold(roleId, (playerInfo.gold + totalGold))
		if DropTreasure then
			self:_cast(M_CatchFish.handleDropThreasure, DropTreasure)
		end
	end
	-- __MONITOR("Room:robotHit", 1)
	return SystemError.success
end

function Room:dropThreasure(playerInfo, hitFish)
	--达到固定消耗后获得1张夺宝卡
	local dropTreasure = 0
	local subGoldIndex

	if playerInfo.costGold >= GET_TREASURE_VALUES[1][1] and playerInfo.costGold < GET_TREASURE_VALUES[2][1] then
		if math.rand() < GET_TREASURE_VALUES[1][2] then
			dropTreasure = 1
			playerInfo.costGold = playerInfo.costGold - GET_TREASURE_VALUES[1][1]
		end
	elseif playerInfo.costGold >= GET_TREASURE_VALUES[2][1] and playerInfo.costGold < GET_TREASURE_VALUES[3][1] then
		if math.rand() < GET_TREASURE_VALUES[2][2] then
			dropTreasure = 1
			playerInfo.costGold = playerInfo.costGold - GET_TREASURE_VALUES[2][1]
		end 
	elseif playerInfo.costGold > GET_TREASURE_VALUES[3][1] then
		dropTreasure = 1
		playerInfo.costGold = playerInfo.costGold - GET_TREASURE_VALUES[3][1]
	else 
		--新手达到固定消耗后获得1张夺宝卡
		if playerInfo.fishTreasure == 0 and playerInfo.totalCostGold >= GOT_TREASURE_GOLD_FOR_NEWBIE then
			dropTreasure = 1
		end
	end
	if dropTreasure == 0 then
		return dropTreasure
	end	
	playerInfo.fishTreasure = playerInfo.fishTreasure + dropTreasure
	self:_cast(M_CatchFish.handleDropThreasure, {roleId = playerInfo.roleId, fishId = hitFish:getObjectId(), treasure = dropTreasure})
	return dropTreasure
end

function Room:hit(hitInfo)
	-- __MONITOR("Room:hit")
	local playerInfo = self._players[hitInfo.roleId]
	if not playerInfo then
		return SystemError.argument
	end
	-- 判断捕鱼命中
	local hitFish, catchFishes, costNotFishGold = self:_doHit(playerInfo, hitInfo)
	
	-- 捕鱼未命中的金币
	playerInfo.notFishGold = playerInfo.notFishGold - costNotFishGold
	
	-- 获得夺宝卡
	local dropTreasure = 0
	if hitFish then
		dropTreasure = self:dropThreasure(playerInfo, hitFish)
	end

	--计算捕鱼掉落
	local dropGold = self:_doDropGold(hitInfo, catchFishes)

	local fishTypeList 
	if not table.empty(catchFishes) then
		fishTypeList = {}
		for _, item in pairs(catchFishes) do
			local fishType = item[1]:getType()
			if fishType == FishType.GOLD_FISH then 
				self:setGoldFishDrop(0)
			end
			fishTypeList[#fishTypeList + 1] = fishType
			item[1]:destroy()
			item[1] = nil
		end
	end

	-- __MONITOR("Room:hit", 1)
	return SystemError.success, {dropGold, dropTreasure, costNotFishGold, fishTypeList, playerInfo.costGold}
end

function Room:updateGun(gunInfo)
	local playerInfo = self._players[gunInfo.roleId]
	playerInfo.gunType = gunInfo.gunType
	playerInfo.gunLevel = gunInfo.gunLevel
	self:_cast(M_CatchFish.handleUpdateGun, gunInfo)
	return SystemError.success
end

function Room:freeze(roleId)
	local now = self:_getNow()
	local timeLen
	if not self._isFrozen then
		self._isFrozen = true
		timeLen = FREEZE_TIME_LEN
		self:_cast(M_CatchFish.handleFreeze, {roleId = roleId, freezeTime = now * 100})
	else
		timeLen = now + FREEZE_TIME_LEN - self._freezeEndTime
	end
	self._freezeTime = now
	self._freezeEndTime = now + FREEZE_TIME_LEN
	for _, fish in pairs(self._fishes) do
		fish:freeze(timeLen)
	end
	return SystemError.success
end

function Room:crit(roleId)
	local playerInfo = self._players[roleId]
	playerInfo.isCrit = true

	return SystemError.success
end

function Room:uncrit(roleId)
	local playerInfo = self._players[roleId]
	playerInfo.isCrit = false
end

function Room:slice(roleId, sliceInfo)
	local playerInfo = self._players[roleId]
	playerInfo.costGold = playerInfo.costGold + sliceInfo.cost
	playerInfo.totalCostGold = playerInfo.totalCostGold + sliceInfo.cost

	local dropGold = 0
	local dropTreasure = 0
	local costNotFishGold = 0
	local catchFishes = {}

	local sliceFish = sliceInfo.sliceFish or {}
	local sliceFishId = sliceFish.fishId
	local fish = self._fishes[sliceFishId]
	if fish and not fish:isDead() then 
		if fish:isBoss() then
			costNotFishGold = costNotFishGold + bullet:getLevel()
			-- 捕鱼未命中的金币
			playerInfo.notFishGold = playerInfo.notFishGold - costNotFishGold
		end

		-- 获得夺宝卡
		dropTreasure = self:dropThreasure(playerInfo, fish)

		-- 命中判断
		dropGold = sliceInfo.cost * fish:getGoldDrop()
		local catch, crit = self:_checkCatch(playerInfo, fish, nil, sliceInfo.pumpRatio, extraRatio, dropGold)
		if catch then
			self._fishes[sliceFishId] = nil
			catchFishes[#catchFishes + 1] = {fish, crit}

			-- 跑马灯
			self:_checkSendMarquee(playerInfo, fish)

			-- 处理 炸弹、瓶子鱼
			local fishIds = self:_getCaughtFishes(fish)
			local fishTypes = {}
			if fishIds then
				for _, fishId in ipairs(fishIds) do
					local f = self._fishes[fishId]
					self._fishes[fishId] = nil
					catchFishes[#catchFishes + 1] = {f, 1}
					fishTypes[#fishTypes+1] = f:getType()
				end
			end
			if fish:getType() == FishType.GLOBAL_BOMB or fish:getType() == FishType.LOCAL_BOMB then
				logger.Pf("roleId:%d,sliceInfo.cost:%d,type:%d,fishTypes:%s", playerInfo.roleId, sliceInfo.cost, fish:getType(), table.concat(fishTypes, ","))
			end
		end
	end

	--计算捕鱼掉落
	local realDropGold = 0
	local fishTypeList = {}
	if not table.empty(catchFishes) then
		local dropInfo = {roleId = roleId, drops = {}}
		for _, item in ipairs(catchFishes) do
			local fish, crit = table.unpack(item)
			if not fish:isBoss() then
				local gold = self:_getDropGlod(fish, nil, sliceInfo.cost)
				crit = crit or 1
				gold = gold * crit
				realDropGold = realDropGold + gold
				table.insert(dropInfo.drops, {fishId = fish:getObjectId(), gold = gold, crit = crit})
			end
			
			local fishType = fish:getType()
			if fishType == FishType.GOLD_FISH then 
				self:setGoldFishDrop(0)
			end
			table.insert(fishTypeList, fishType)
			fish:destroy()
		end
		self:_cast(M_CatchFish.handleDrop, dropInfo)
	end
	catchFishes = {}

	-- 广播切鱼	
	sliceInfo.roleId = roleId
	sliceInfo.cost = nil
	sliceInfo.pumpRatio = nil
    sliceInfo.bossAp = nil
	self:_cast(M_CatchFish.onSlice, sliceInfo, roleId)

	return SystemError.success, {realDropGold, dropTreasure, costNotFishGold, fishTypeList, playerInfo.costGold}
end

function Room:updateGold(roleId, gold, exclude)
	local playerInfo = self._players[roleId]
	playerInfo.gold = gold
	self:_cast(M_CatchFish.handlePlayerGoldUpdate, {roleId = roleId, gold = gold}, exclude and roleId)
	return SystemError.success
end

function Room:updateRoleInfo(roleId, updateInfo, exclude)
	local playerInfo = self._players[roleId]
	local UpdatePlayerInfo = {}	
	UpdatePlayerInfo.roleId = UpdatePlayerInfo
	for k,v in pairs(updateInfo) do
		playerInfo[k] = v
		UpdatePlayerInfo[k] = v
	end
	self:_cast(M_CatchFish.handlePlayerInfoUpdate, UpdatePlayerInfo, exclude and roleId)
	return SystemError.success
end

function Room:updateNotFishGold(roleId, notFishGold, noviceGold, chargeStatus)
	local playerInfo = self._players[roleId]
	playerInfo.notFishGold = notFishGold
	playerInfo.novice = noviceGold
	playerInfo.chargeStatus = chargeStatus
	return SystemError.success
end

function Room:updateVip(roleId, isVip)
	local playerInfo = self._players[roleId]
	playerInfo.isVip = isVip
	return SystemError.success
end

function Room:chat(chatInfo)
	self:_cast(M_Chat.handleSpeakToWorld, chatInfo)
end

function Room:bornBosses(bossInfos, send)
	local fishes = {}
	for _, info in pairs(bossInfos) do
		local fish = BossObject.new({
				objectId = info.objectId,
				type = info.type,
				pathId = info.pathId,
				bornX = 0,
				bornY = 0,
				rotation = info.rotation,
				bornTime = info.bornTime - self._createTime,
				aliveTime = info.aliveTime,
				children = info.children,
				prizeId = info.prizeId,
			})
		self._fishes[info.objectId] = fish
		fishes[#fishes + 1] = fish:getInfo()
	end

	if send then
		self:_cast(M_CatchFish.handleFishBorn, {fishes = fishes})
	end
end

function Room:killBoss(bossId)
	local fish = self._fishes[bossId]
	if fish then
		fish:destroy()
	end
	self._fishes[bossId] = nil
end

function Room:cast(proto, data, exclude)
	self:_cast(proto, data, exclude)
end

function Room:update(dt)
	-- print("Room:update fishes num:"..table.nums(self._fishes))
	self._timeStamp = (self._timeStamp or 0) + dt
	
	if self._isFrozen then
		if self._freezeEndTime > self:_getNow() then
			return
		else
			self._isFrozen = false
			self:_cast(M_CatchFish.handleUnfreeze)
		end
	end
	for objectId, fish in pairs(self._fishes) do
		fish:update(dt)

		-- 更新鱼的赔率
		if fish:getType() == FishType.GOLD_FISH and not fish:isDead() and not fish:isMovedOut() and self._timeStamp > 1  then 
			self._timeStamp = 0
			local oldGoldDrop = fish:getGoldDrop()
			fish:updateGoldDrop()
			local newGoldDrop = fish:getGoldDrop()
			if oldGoldDrop ~= newGoldDrop then 
				local upFishInfo = {objectId = fish:getObjectId(), goodDrop = newGoldDrop}
				-- dump(upFishInfo)
				self:_cast(M_CatchFish.onUpFishInfo, upFishInfo)
				self:setGoldFishDrop(newGoldDrop)
			end 
		end 

		if fish:isMovedOut() then
			local fish = self._fishes[objectId]
			if fish then
				fish:destroy()
			end
			self._fishes[objectId] = nil
		end
	end

	self:_updateTimers(dt)
end

function Room:_scheduleBornFish()
	for index, item in ipairs(FishRefresh) do
		self._bornTimers[#self._bornTimers + 1] = self:_addTimer(item.interval, function()
				self:_fishBorn(item.type)
			end)
	end

	self:_addTimer(FISH_STRIKES_BORN_INTERVAL, function()
			for _, handle in ipairs(self._bornTimers) do
				self:_removeTimer(handle)
			end
			self._bornTimers = {}

			for _, fish in pairs(self._fishes) do
				fish:setDead()
				fish:destroy()
			end
			self._fishes = {}

			self:_cast(M_CatchFish.handleFishStrikes)
			self:_addTimer(FISH_STRIKES_ONE_WAVE_TIME, handler(self, self._fishStrikesBorn), FISH_STRIKES_WAVE_COUNT)
		end, 1)
end

function Room:_doHit(playerInfo, hitInfo)
	local hitFish
	local costNotFishGold = 0
	local bullets = playerInfo.bullets
	local catchFishes = {}
	for _, hit in ipairs(hitInfo.hits) do
		local bullet = bullets[hit.bulletId]
		if bullet then
			bullets[hit.bulletId] = nil
			local fish = self._fishes[hit.fishId]
			if fish then
				-- 囤金鱼积累金币
				fish:addBulletGold(bullet:getLevel())

				hitFish = fish

				if fish:isBoss() then
					costNotFishGold = costNotFishGold + bullet:getLevel()
				end

				local extraRatio = 1
				if playerInfo.isCrit then
					extraRatio = extraRatio + 0.2
				end

				if bullet:getType() == CatchFishConst.CHENG_JIE then
					self:_doChengJieGun(playerInfo, hit, bullet, hitInfo.pumpRatio, catchFishes)
				else
					local catch, crit = self:_checkCatch(playerInfo, fish, bullet, hitInfo.pumpRatio, extraRatio)
					if catch then
						self._fishes[hit.fishId] = nil
						catchFishes[#catchFishes + 1] = {fish, bullet, crit}
						self:_checkSendMarquee(playerInfo, fish)
						local fishIds = self:_getCaughtFishes(fish)
						local fishTypes = {}
						if fishIds then
							for _, fishId in ipairs(fishIds) do
								local f = self._fishes[fishId]
								self._fishes[fishId] = nil
								catchFishes[#catchFishes + 1] = {f, bullet, 1}
								fishTypes[#fishTypes+1] = f:getType()
							end
						end
						if fish:getType() == FishType.GLOBAL_BOMB or fish:getType() == FishType.LOCAL_BOMB then
							logger.Pf("roleId:%d,bulletLevel:%d,type:%d,fishTypes:%s", playerInfo.roleId, bullet:getLevel(), fish:getType(), table.concat(fishTypes, ","))
						end
					end
					if bullet:getType() == CatchFishConst.JI_GUANG_GUN and math.rand(0, 1) <= HIT_EXTRA_RATIO then
						self:_doJiGuangGun(playerInfo, hit, bullet, hitInfo.pumpRatio, catchFishes)
					end
				end
			end
		end
	end
	return hitFish, catchFishes, costNotFishGold
end

function Room:_doDropGold(hitInfo, catchFishes)
	local dropGold = 0
	if not table.empty(catchFishes) then
		local dropInfo = {roleId = hitInfo.roleId}
		local drops = {}
		for _, item in ipairs(catchFishes) do
			local fish, bullet, crit = table.unpack(item)
			if not fish:isBoss() then
				local gold = self:_getDropGlod(fish, bullet)
				crit = crit or 1
				gold = gold * crit
				dropGold = dropGold + gold
				drops[#drops + 1] = {fishId = fish:getObjectId(), gold = gold, crit = crit}
			end
		end
		dropInfo.drops = drops
		self:_cast(M_CatchFish.handleDrop, dropInfo)
	end
	return dropGold
end 

-- 捕鱼伪概率控制
function Room:_checkCatch(playerInfo, fish, bullet, pumpRatio, extraRatio, dropGold)
	if not fish or fish:isDead() or not fish:isBorned() then
		return false
	end

	assert(bullet or dropGold)
	if bullet then 
		dropGold = fish:getGoldDrop() * bullet:getLevel()
	end

	-- 2017.4.5 修改 非 VIP 玩家，金币数量不能超过一万
	if playerInfo.isVip == false then
		if dropGold + playerInfo.gold > self._maxGoldOfFreePlayer then
			return false
		end
	end

	-- VIP 玩家
	if playerInfo.isVip then
		local maxRatio
		local recharge = playerInfo.notFishGold / 5500

		if recharge <= 200 then
			maxRatio = math.max(1.36, -1.48 * math.log(recharge) + 11.578)
		else
			maxRatio = math.max(1.36, 33.91 * (recharge ^ -0.449))
		end

		if playerInfo.deviceRoleCount > 10 and playerInfo.deviceRoleCount < 500 then
			maxRatio = 1
		elseif playerInfo.deviceRoleCount >= 500 then
			maxRatio = 0.4
		end
		
		if playerInfo.gold + playerInfo.fishTreasure * EXPECTED_GET_TREASURE_RATIO < playerInfo.notFishGold * maxRatio then
			if (playerInfo.gold + dropGold) + playerInfo.fishTreasure * EXPECTED_GET_TREASURE_RATIO >= playerInfo.notFishGold * maxRatio then
				return false
			end
	    end
	end

    extraRatio = extraRatio or 1

    local crit
    if bullet and bullet:getType() == CatchFishConst.SHUANG_SHENG_ZHI_LI then
    	local fishDrop = fish:getGoldDrop()
    	if fishDrop < 10 then
    		extraRatio  = extraRatio * 0.9091
    		crit = math.rand() <= 0.1
    	elseif fishDrop >= 10 and fishDrop < 50 then
    		extraRatio  = extraRatio * 0.8333
    		crit = math.rand() <= 0.2
    	elseif fishDrop >= 50 and fishDrop < 100 then
    		extraRatio  = extraRatio * 0.7692
    		crit = math.rand() <= 0.3
    	end
	end

	crit = crit and 2 or 1

	if bullet and bullet:getType() == CatchFishConst.JIE_NENG then
		extraRatio  = extraRatio * 0.96
	end

	if bullet and bullet:getType() == CatchFishConst.GOLD_GUN then
		extraRatio  = extraRatio * 0.99
	end

	-- 2017.4.5 版本概率
	-- local baseRatio = 1 / fish:getGoldDrop() * (1 - 0.08)
	local CP = bullet and bullet:getCP() or 0
	local TP = pumpRatio
	local PB = self:_getPB(playerInfo, fish)
	local ratio = fish:getNormalRatio() * (1 + TP) * (1 + CP) * PB * extraRatio
	return math.rand() <= ratio, crit
end

function Room:_checkBossCatch(playerInfo, fish, bullet, bossAp)
	if not fish or fish:isDead() then
		return false
	end

	local ratio = bullet:getLevel() / fish:getWorth() * bossAp
	local catch = math.rand() <= ratio
	if catch then
		context.sendS2S(SERVICE.CATCH_FISH, "killBoss", 
			{
				objectId = fish:getObjectId(),
				nickname = playerInfo.nickname,
				roleId = playerInfo.roleId,
			})
	end
	return catch
end

function Room:_getPB(playerInfo, fish)
	local pb = 1

	local items = PersonalBenefit[fish:getBenefitGroup()]
	if not items then
		return pb
	end
	
	local novice = 0
	if self:isProtect() then
		novice = playerInfo.novice
	end
	local notFishGold = playerInfo.notFishGold
	local gold = playerInfo.gold
	local fishTreasure = math.max(0, playerInfo.fishTreasure - 1)
	
	-- if playerInfo.isVip and playerInfo.deviceRoleCount > 2 then
	-- 	notFishGold = notFishGold + playerInfo.deviceNotFishGold
	-- 	gold = gold + playerInfo.deviceGold
	-- 	fishTreasure = fishTreasure + playerInfo.deviceFishTreasure
	-- end
	local scale = (novice + notFishGold) / (math.max(1, gold) / EXPECTED_GET_TREASURE_RATIO + fishTreasure)
	local index = math.min(#items, table.lowerBound(items, scale, "scale"))
	local conf = items[index]
	if conf then
		pb = conf.rate / 10000
	end
	return pb
end

function Room:_checkSendMarquee(playerInfo, fish)
	if fish:isBoss() then
		return
	end
	local sendMarquee = fish:getSendMarquee()
	if sendMarquee > 0 and sendMarquee <= self._sendMarquee then
		context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 1, words = {playerInfo.nickname, fish:getName()}})
	end
end

function Room:_getDropGlod(fish, bullet, bulletLevel)
	assert(bullet or bulletLevel)
	if bulletLevel then 
		return fish:getCaughtGoldDrop() * bulletLevel
	end
	return fish:getCaughtGoldDrop() * bullet:getLevel()
end

function Room:_getDropTreasure(fish, bullet)
	local count = 0
	if math.rand() < fish:getTreasureDrop() / 10000 then
		count = 1
	end
	return count
end

function Room:getJiGuangGunExtraFishes()
	local extraFishIdList = {}
	local count = math.rand(2, 5)
	local total = table.nums(self._fishes)
	local extraFishes = {}
	for i = 1, count do
		if total <= 0 then
			break
		end
		local index = math.rand(1, total)
		for fishId, fish in pairs(self._fishes) do
			index = index - 1
			if index == 0 then
				extraFishes[#extraFishes + 1] = fish
				self._fishes[fishId] = nil
				table.insert(extraFishIdList, fishId)
				break
			end
		end
	end

	for _, fish in ipairs(extraFishes) do
		self._fishes[fish:getObjectId()] = fish
	end
	return extraFishIdList
end

function Room:_doJiGuangGun(playerInfo, hit, bullet, pumpRatio, catchFishes)
	hit.bulletType = bullet:getType()
	hit.extraFishes = self:getJiGuangGunExtraFishes()
	local num = table.nums(hit.extraFishes)
	local fixRatio = 1
	if num > 0 then
		fixRatio = fixRatio / num
	end

	for _, fishId in ipairs(hit.extraFishes) do
		local fish = self._fishes[fishId]
		if fish and not fish:isBoss() and self:_checkCatch(playerInfo, fish, bullet, pumpRatio, fixRatio) then
			self._fishes[fishId] = nil
			catchFishes[#catchFishes + 1] = {fish, bullet}
			self:_checkSendMarquee(playerInfo, fish)
			local fishIds = self:_getCaughtFishes(fish)
			local fishTypes = {}
			if fishIds then
				for _, fishId in ipairs(fishIds) do
					local f = self._fishes[fishId]
					self._fishes[fishId] = nil
					catchFishes[#catchFishes + 1] = {f, bullet, 1}
					fishTypes[#fishTypes+1] = f:getType()
				end
			end
			if fish:getType() == FishType.GLOBAL_BOMB or fish:getType() == FishType.LOCAL_BOMB then
				logger.Pf("roleId:%d,bulletLevel:%d,type:%d,fishTypes:%s", playerInfo.roleId, bullet:getLevel(), fish:getType(), table.concat(fishTypes, ","))
			end
		end
	end
	self:_cast(M_CatchFish.handleHit, {roleId = playerInfo.roleId, hits = {hit}})
end

function Room:_doChengJieGun(playerInfo, hit, bullet, pumpRatio, catchFishes)
	local hitFish = self._fishes[hit.fishId]
	if hitFish then
		local hitFishIds = self:_getRangeFishes(hitFish, CHENG_JIE_GUN_RANGE)
		local count = table.nums(hitFishIds)		
		for _, fishId in ipairs(hitFishIds) do
			local fish = self._fishes[fishId]
			if fish and not fish:isBoss() and self:_checkCatch(playerInfo, fish, bullet, pumpRatio, 1 / count) then
				self._fishes[fishId] = nil
				catchFishes[#catchFishes + 1] = {fish, bullet}
				self:_checkSendMarquee(playerInfo, fish)
				local fishIds = self:_getCaughtFishes(fish)
				local fishTypes = {}
				if fishIds then
					for _, fishId in ipairs(fishIds) do
						local f = self._fishes[fishId]
						self._fishes[fishId] = nil
						catchFishes[#catchFishes + 1] = {f, bullet, 1}
						fishTypes[#fishTypes+1] = f:getType()
					end
				end
				if fish:getType() == FishType.GLOBAL_BOMB or fish:getType() == FishType.LOCAL_BOMB then
					logger.Pf("roleId:%d,bulletLevel:%d,type:%d,fishTypes:%s", playerInfo.roleId, bullet:getLevel(), fish:getType(), table.concat(fishTypes, ","))
				end
			end
		end
	end
end

function Room:setGoldFishDrop(goldDrop)
	self._goldFishDrop = goldDrop
end

function Room:_fishBorn(type)
	local roomTime = self:_getNow()
	-- 超大鱼出生时，机器人瞄准目标
	if type == CatchFishConst.FishGroupType.BIGGEST_FISH then 
		for roleId,playerInfo in pairs(self._players or {}) do
			if playerInfo.isRobot then
				if math.rand(100) < 20 then 
					playerInfo.isAim = true	
					break
				end
			end
		end
	end 

	--随机鱼类型
	local fishGroups = FishGroupTypeConf[type]
	local groupId = fishGroups[math.rand(1, #fishGroups)]
	local fishGroup = FishGroupConf[groupId]
	
	--随机选择游动路线
	local pathGroups = FishPathGroupConf[fishGroup.pathGroup]
	local pathId = pathGroups[math.rand(1, #pathGroups)]
	local path = FishPathConf[pathId]
	
	-- 超大鱼延时5秒出生
	local originalDelay = 0
	if type == FishType.GOLD_FISH then 
		originalDelay = 5
	end

	local lastFish
	local bornCount = 0
	local curdelay = originalDelay
	local curRotation = 0
	local fishes = {}

	while bornCount < fishGroup.count do
		for _, rule in ipairs(fishGroup.bornRule) do
			local type, count, interval, rotation, children = table.unpack(rule)
			rotation = math.rad(rotation or 0)
			count = math.min(fishGroup.count - bornCount, math.max(1, count))
			-- 设置囤金鱼倍率
			local fixGoldDrop
			if type == FishType.GOLD_FISH and self._goldFishDrop and self._goldFishDrop > 0 then 
				fixGoldDrop = self._goldFishDrop
			end
			for i = 1, count do
				local fish = FishObject.new({
						objectId = self._nextObjectId,
						type = type,
						pathId = path.id,
						bornX = 0,
						bornY = 0,
						rotation = curRotation,
						bornTime = roomTime + curdelay,
						aliveTime = -curdelay,
						children = children,
						fixGoldDrop = fixGoldDrop,	-- 修正金币赔率
					})
				self._fishes[self._nextObjectId] = fish
				fishes[#fishes + 1] = fish:getInfo()
				self._nextObjectId = self._nextObjectId + 1
				curdelay = curdelay + interval
				curRotation = curRotation + rotation
				bornCount = bornCount + 1
				lastFish = fish
			end
			if bornCount == fishGroup.count then
				break
			end
		end
	end

	self:_cast(M_CatchFish.handleFishBorn, {fishes = fishes})

	if lastFish then
		curdelay = curdelay + lastFish:getMoveOutTimeLen()
	end
	return curdelay - originalDelay
end

function Room:_fishStrikesBorn()
	local total = 0
	for _, item in ipairs(FishStrikesRefresh) do
		total = total + item.ratio
	end

	local types
	local ratio = math.rand(1, total)
	local curRatio = 0
	for _, item in ipairs(FishStrikesRefresh) do
		curRatio = curRatio + item.ratio
		if curRatio >= ratio then
			types = item.types
			break
		end
	end

	local totalDelay = 0
	for i = 0, #types, 2 do
		local delay = types[i] or 0
		local fishGroupTypes = types[i + 1]
		totalDelay = totalDelay + delay
		for j, fishGroupType in ipairs(fishGroupTypes) do
			self:_addTimer(totalDelay, function()
				local overTime = self:_fishBorn(fishGroupType) or 0
				if i + 1 == #types and j == #fishGroupTypes then
					self:_addTimer(overTime - MIN_BORN_INTERVAL, handler(self, self._scheduleBornFish), 1)
				end
			end, 1)
		end
	end
end

function Room:_cast(proto, data, exclude)
	local roleIds = {}
	for _, playerInfo in pairs(self._players or {}) do
		if playerInfo.roleId ~= exclude and not playerInfo.isRobot then
			roleIds[#roleIds + 1] = playerInfo.roleId
		end
	end
	context.sendMultiS2C(roleIds, proto, data)
end

function Room:_getFirePosition(pos)
	local v = GUN_POS[pos]
	return v[1], v[2]
end

function Room:_getPlayerInfo(info)
	-- local bullets = {}
	-- for bulletId, bullet in pairs(info.bullets) do
	-- 	bullets[#bullets + 1] = bullet:getInfo()
	-- end
	return {
		roleId = info.roleId,
		pos = info.pos,
		nickname = info.nickname,
		avatar = info.avatar,
		gold = info.gold,
		gunType = info.gunType,
		gunLevel = info.gunLevel,
		aimObjectId = info.aimObjectId,
		-- bullets = bullets,
		level = info.level,
	}
end

-- 房间运行时间
function Room:_getNow()
	return skynet.time() - self._createTime
end

function Room:_getCaughtFishes(hittedFish)
	local fishType = hittedFish:getType()
	if fishType == FishType.SAME_FISH then
		return self:_getSameFishes(hittedFish:getChildren()[1])
	elseif fishType == FishType.LOCAL_BOMB then
		return self:_getRangeFishes(hittedFish, LOCAL_BOMB_RANGE)
	elseif fishType == FishType.GLOBAL_BOMB then
		return self:_getViewPortFishes()
	else
		return nil
	end
end

function Room:_getSameFishes(type)
	local fishes = {}
	for fishId, fish in pairs(self._fishes) do
		if fish:getType() == type and fish:isBorned() then
			fishes[#fishes + 1] = fishId
		end
	end

	return fishes
end

-- 获得指定鱼周围半径X的所有鱼
function Room:_getRangeFishes(obj, radius)
	local fishes = {}
	local objX, objY = obj:getX(), obj:getY()
	for fishId, fish in pairs(self._fishes) do
		if fish:isBorned() and not fish:isBoss() 
			and fish:getType() ~= FishType.GLOBAL_BOMB then
			local dx, dy = fish:getX() - objX, fish:getY() - objY
			local distance = math.sqrt(dx * dx + dy * dy)
			if distance <= radius then
				fishes[#fishes + 1] = fishId
			end
		end
	end

	return fishes
end

function Room:_getViewPortFishes()
	local fishes = {}
	for fishId, fish in pairs(self._fishes) do
		if fish:isBorned() and not fish:isBoss() 
			and fish:getX() >= 0 and fish:getX() <= 1024
			and fish:getY() >= 0 and fish:getY() <= 576 then
			fishes[#fishes + 1] = fishId
		end
	end

	return fishes
end

function Room:_addTimer(interval, callback, times)
	self._timerHandle = self._timerHandle + 1
	self._timers[self._timerHandle] = {interval = interval, callback = callback, times = times, time = 0}
	return self._timerHandle
end

function Room:_removeTimer(handle)
	self._timers[handle] = nil
end

function Room:_updateTimers(dt)
	for handle, timer in pairs(self._timers) do
		timer.time = timer.time + dt
		if timer.time >= timer.interval then
			timer.callback()
			if timer.times then
				timer.times = timer.times - 1
				if timer.times == 0 then
					self._timers[handle] = nil
				end
			end
			timer.time = 0
		end
	end
end

return Room