local skynet = require("skynet")
local logger = require("log")
local context = require("common.context")
local roleCtrl = require("role.role_ctrl")
local resOp = require("common.res_operate")
local dbHelp = require("common.db_help")
local taskCtrl = require("task.task_ctrl")

local configDb = require("config.config_db")
local gunConf = configDb.gun
local gunLevelMap = configDb.gun_level_map
local arenaConfig = configDb.arena_config
local gunLevelUnlockConf = configDb.power_unlock_config

local logConst = require("game.log_const")
local roleConst = require("role.role_const")
local TaskType = require("task.task_const").TaskType
local CatchFishConst = require("catch_fish.catch_fish_const")

local catchFishImpl = {}

local CREATE_VIP_ROOM_COST = 10000
local MIN_GUN_LEVEL = 10

local CRIT_TIME_LEN = 5		--狂暴时长
local VIP_ROOM_LEVEL_LIMIT = {100, 200, 500, 1000, 2000, 5000}

local curUsedGunInfo
local isDoingArena
local isCrit

local function getEnterInfo(roleId, roomId)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	local info = {
		roomId = roomId,
		roleId = roleId,
		nickname = roleInfo.nickname,
		avatar = roleInfo.avatar,
		gold = roleInfo.gold,
		gunType = roleInfo.gun,
		gunLevel = roleInfo.gunLevel,
		channelId = roleInfo.channelId,
		stock = roleInfo.stock or 0,
		notFishGold = roleInfo.notFishGold or 0,
		costGold = roleInfo.costGold or 0,
		fishTreasure = roleInfo.fishTreasure or 0,
		novice = roleInfo.novice or 0,
		isVip = roleInfo.isVip,
		chargeStatus = roleInfo.chargeStatus ~= false,
		totalCostGold = roleInfo.totalCostGold or 0,
		imei = roleInfo.imei,
		deviceRoleCount = roleInfo.deviceRoleCount or 1,
		deviceNotFishGold = roleInfo.deviceNotFishGold or 0,
		deviceGold = roleInfo.deviceGold or 0,
		deviceFishTreasure = roleInfo.deviceFishTreasure or 0,
		level = roleInfo.level or 1,
	}
	
	local onlineSecs = roleCtrl.getOnlineSecs(roleId)
	if not onlineSecs or onlineSecs < 180 then 
		info.isNewPlayer = true
	end
	return info
end

function catchFishImpl.enterRoom(roleId)
	if context.catchFishSvc then
		context.callS2S(SERVICE.CATCH_FISH, "leave", roleId)
		context.catchFishSvc = nil
	end

	local info = getEnterInfo(roleId, nil)
	
	local ec, catchFishSvc, roomInfo = context.callS2S(SERVICE.CATCH_FISH, "enter", info)
	if ec ~= SystemError.success then
		return ec
	end
	context.catchFishSvc = catchFishSvc
	curUsedGunInfo = {gunType = info.gunType, gunLevel = info.gunLevel, fireTime = skynet.now()}
	isDoingArena = false
	return ec, roomInfo
end	

function catchFishImpl.leaveRoom(roleId)
	if context.catchFishSvc then
		context.callS2S(SERVICE.CATCH_FISH, "leave", roleId)
		context.catchFishSvc = nil
		-- curUsedGunInfo = nil
	end
	return SystemError.success
end

function catchFishImpl.fire(roleId, fireInfo)
	if not context.catchFishSvc then
		return SystemError.illegalOperation
	end

	local conf = gunConf[curUsedGunInfo.gunType]
	local now = skynet.now()

	-- if now - curUsedGunInfo.fireTime < conf.fireInterval / 10 * fireInfo.times then
	-- 	return CatchFishError.fireCding
	-- end
	curUsedGunInfo.fireTime = now

	--扣除资源
	local cost = conf.cost * curUsedGunInfo.gunLevel
	-- if isCrit then
	-- 	cost = cost * 2
	-- end

	if not isDoingArena then
		if curUsedGunInfo.gunType == CatchFishConst.JIE_NENG then
			if math.rand() <= 0.08 then
				cost = cost/2
				context.sendS2C(roleId, M_CatchFish.handleJieNeng)
			end
		end

		local ec = resOp.costGold(roleId, cost, logConst.shotCost)
		if ec ~= SystemError.success then
			return ec
		end
		if curUsedGunInfo.gunType == CatchFishConst.BING_DONG then
			roleCtrl.addFrozenGunCost(roleId, curUsedGunInfo.gunLevel)
		elseif curUsedGunInfo.gunType == CatchFishConst.CRIT then
			roleCtrl.addCritGunCost(roleId, curUsedGunInfo.gunLevel)
		elseif curUsedGunInfo.gunType == CatchFishConst.SLICE_GUN then
			roleCtrl.addSliceGunCost(roleId, curUsedGunInfo.gunLevel)
		end
	end

	fireInfo.roleId = roleId
	local ec, costGold = context.callS2S(context.catchFishSvc, "fire", fireInfo, cost)
	if ec == SystemError.success and costGold then 
		roleCtrl.setCostGold(roleId, costGold)
	end
	return ec
end


function catchFishImpl.robotHit(roleId, hitInfo)
	if not context.catchFishSvc then
		return SystemError.illegalOperation
	end
	
	local ec, result = context.callS2S(context.catchFishSvc, "robotHit", roleId, hitInfo)
	return ec
end

function catchFishImpl.onHit(roleId, dropGold, dropTreasure, costNotFishGold, fishTypeList, costGold)
	if dropGold > 0 then
		resOp.send(roleId, roleConst.GOLD_ID, dropGold, logConst.shotGet)
	end

	if dropTreasure > 0 then
		resOp.send(roleId, roleConst.TREASURE_ID, dropTreasure, logConst.shotGet)
	end

	if costGold > 0 then 
		roleCtrl.setCostGold(roleId, costGold)
	end

	if costNotFishGold > 0 then
		roleCtrl.addNotFishGold(roleId, -costNotFishGold, true)
		context.sendS2S(SERVICE.CATCH_FISH, "updateBossAp", costNotFishGold)
	end

	-- 捕获到鱼，更新每日任务
	if dropGold > 0 and fishTypeList then
		for _, fishType in ipairs(fishTypeList) do
			taskCtrl.incrTaskStep(roleId, TaskType.FishShot, 1, fishType)
		end
	end

	--彩金炮加成
	if curUsedGunInfo.gunType == CatchFishConst.GOLD_GUN and dropGold > 0 then
		local add = dropGold * 0.02
		roleCtrl.addGoldGunPrize(roleId, add)
	end
end

function catchFishImpl.hit(roleId, hitInfo)
	if not context.catchFishSvc then
		return SystemError.illegalOperation
	end
	hitInfo.roleId = roleId
	local ec, result = context.callS2S(context.catchFishSvc, "hit", hitInfo)
	if ec ~= SystemError.success then
		return ec
	end
	
	-- 处理捕鱼命中（任务，修改 bossAP 等）
	local dropGold, dropTreasure, costNotFishGold, fishTypeList, costGold = table.unpack(result)
	catchFishImpl.onHit(roleId, dropGold, dropTreasure, costNotFishGold, fishTypeList, costGold)
	return ec
end

function catchFishImpl.aim(roleId, aimInfo)
	if not context.catchFishSvc then
		return SystemError.illegalOperation
	end

	aimInfo.roleId = roleId
	return context.callS2S(context.catchFishSvc, "aim", aimInfo)
end

function catchFishImpl.stopAim(roleId)
	if not context.catchFishSvc then
		return SystemError.illegalOperation
	end

	return context.callS2S(context.catchFishSvc, "stopAim", roleId)
end

function catchFishImpl.updateGun(roleId, gunInfo)
	--检查是否有此炮塔
	local levels = gunLevelMap[gunInfo.gunType]
	if not levels then
		logger.Errorf("catchFishImpl.updateGun(roleId:%s, gunInfo:%s)", roleId, dumpString(gunInfo))
		return SystemError.argument
	end
	if not levels[gunInfo.gunLevel] then
		logger.Errorf("catchFishImpl.updateGun(roleId:%s, gunInfo:%s)", roleId, dumpString(gunInfo))
		return SystemError.argument
	end

	-- if not isDoingArena then
	-- 	local roleInfo = roleCtrl.getRoleInfo(roleId)
	-- 	for _, item in ipairs(gunLevelUnlockConf) do
	-- 		if gunInfo.gunLevel >= item.power then
	-- 			if roleInfo.chargeNum < item.recharge then
	-- 				return CatchFishError.gunLevelUnlock
	-- 			else
	-- 				break
	-- 			end
	-- 		end
	-- 	end
	-- end

	local ec = roleCtrl.updateGun(roleId, gunInfo.gunType)
	if ec ~= SystemError.success then
		return CatchFishError.noHaveGunType
	end

	if not context.catchFishSvc then
		return SystemError.success
	end

	gunInfo.roleId = roleId
	local ec = context.callS2S(context.catchFishSvc, "updateGun", gunInfo)
	if ec ~= SystemError.success then
		return ec
	end

	if isCrit and gunInfo.gunType ~= CatchFishConst.CRIT then
		isCrit = false
		context.sendS2S(context.catchFishSvc, "uncrit", roleId)
	end

	curUsedGunInfo = {gunType = gunInfo.gunType, gunLevel = gunInfo.gunLevel, fireTime = skynet.now()}

	return ec
end

function catchFishImpl.freeze(roleId)
	if not context.catchFishSvc then
		return SystemError.illegalOperation
	end
	--检查当前炮类型
	if curUsedGunInfo.gunType ~= CatchFishConst.BING_DONG then
		return SystemError.illegalOperation
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if roleInfo.frozenGoldCost < roleConst.frozenEnergyMax then
		return CatchFishError.energyNotFull
	end

	local ec = context.callS2S(context.catchFishSvc, "freeze", roleId)
	if ec == SystemError.success then
		roleCtrl.clearFrozenGunCost(roleId)
	end
	return ec
end

function catchFishImpl.crit(roleId)
	if not context.catchFishSvc then
		return SystemError.illegalOperation
	end
	--检查当前炮类型
	if curUsedGunInfo.gunType ~= CatchFishConst.CRIT then
		return SystemError.illegalOperation
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if roleInfo.critGoldCost < roleConst.critEnergyMax then
		return CatchFishError.energyNotFull
	end

	local ec = context.callS2S(context.catchFishSvc, "crit", roleId)
	if ec == SystemError.success then
		roleCtrl.clearCritGunCost(roleId)
		isCrit = true
		skynet.timeout(CRIT_TIME_LEN*100, function()
			if isCrit then
				isCrit = false
				context.sendS2S(context.catchFishSvc, "uncrit", roleId)
			end
		end)
	end
	return ec
end

-- 切鱼结束时间
local sliceEndedAt = 0
local sliceRecord = {}

-- 切鱼
function catchFishImpl.slice(roleId, sliceInfo)
	if not context.catchFishSvc then
		return SystemError.illegalOperation
	end

	-- 检查当前炮类型
	if curUsedGunInfo.gunType ~= CatchFishConst.SLICE_GUN then
		logger.Errorf("catchFishImpl.slice(roleId:%s, sliceInfo:%s) gunType:%s", roleId, dumpString(sliceInfo), curUsedGunInfo.gunType)
		return SystemError.illegalOperation
	end

	-- 切鱼时间校验
	local now = skynet.time()
	if sliceEndedAt < now then 
		-- 能量是否足够
		local roleInfo = roleCtrl.getRoleInfo(roleId)
		if roleInfo.sliceGoldCost < roleConst.sliceEnergyMax then
			return CatchFishError.energyNotFull
		end

		skynet.timeout(CatchFishConst.SLICE_TIME * 100, function()
			context.sendS2C(roleId, M_CatchFish.onSliceFinish)
		end)

		-- 清除能量
		roleCtrl.clearSliceGunCost(roleId)
		
		-- 设置切鱼过期时间（时间差一秒）
		sliceEndedAt = now + CatchFishConst.SLICE_TIME + 1

		-- 重置切鱼记录
		sliceRecord = {}
	end

	-- 检查金币是否足够
	sliceInfo.cost = curUsedGunInfo.gunLevel
	local ec = resOp.costGold(roleId, sliceInfo.cost, logConst.shotCost)
	if ec ~= SystemError.success then
		return ec
	end
	
	-- 切鱼间隔校验
	local sec = math.floor(now)
	sliceRecord[sec] = (sliceRecord[sec] or 0) + 1
	if sliceRecord[sec] > CatchFishConst.SLICE_RATE then 
		logger.Errorf("catchFishImpl.slice(roleId:%s, sliceInfo:%s) sliceRecord:%s", roleId, dumpString(sliceInfo), dumpString(sliceRecord))
		return CatchFishError.invalidSliceRate
	end
	
	-- 通知捕鱼服务
	local ec, result = context.callS2S(context.catchFishSvc, "slice", roleId, sliceInfo)
	if ec ~= SystemError.success then
		return ec
	end
	
	-- 处理捕鱼命中（任务，修改 bossAP 等）
	local dropGold, dropTreasure, costNotFishGold, fishTypeList, costGold = table.unpack(result)
	catchFishImpl.onHit(roleId, dropGold, dropTreasure, costNotFishGold, fishTypeList, costGold)
	return ec
end

function catchFishImpl.createVipRoom(roleId, createInfo)
	--扣除资源
	local ec = resOp.costGold(roleId, CREATE_VIP_ROOM_COST, logConst.createVipRoomCost)
	if ec ~= SystemError.success then
		return ec
	end

	--离开当前房间
	if context.catchFishSvc then
		context.callS2S(SERVICE.CATCH_FISH, "leave", roleId)
		context.catchFishSvc = nil
	end

	if createInfo.minGunLevel == 0 then
		createInfo.minGunLevel = MIN_GUN_LEVEL
	else
		local found = false
		for _, v in ipairs(VIP_ROOM_LEVEL_LIMIT) do
			if v == createInfo.minGunLevel then
				found = true
				break
			end
		end

		if not found then
			return SystemError.argument
		end
	end

	local info = getEnterInfo(roleId, nil)
	info.password = createInfo.password
	info.minGunLevel = createInfo.minGunLevel

	local ec, catchFishSvc, roomInfo = context.callS2S(SERVICE.CATCH_FISH, "createVipRoom", info)
	if ec ~= SystemError.success then
		return ec
	end

	context.catchFishSvc = catchFishSvc
	curUsedGunInfo = {gunType = info.gunType, gunLevel = roomInfo.minGunLevel, fireTime = skynet.now()}
	isDoingArena = false

	return ec, roomInfo
end

function catchFishImpl.enterVipRoom(roleId, enterInfo)
	local info = getEnterInfo(roleId, enterInfo.roomId)
	info.password = enterInfo.password
	
	local ec, catchFishSvc, roomInfo = context.callS2S(SERVICE.CATCH_FISH, "enterVipRoom", info)
	if ec ~= SystemError.success then
		return ec
	end

	context.catchFishSvc = catchFishSvc
	curUsedGunInfo = {gunType = info.gunType, gunLevel = roomInfo.minGunLevel, fireTime = skynet.now()}
	isDoingArena = false

	return ec, roomInfo
end

function catchFishImpl.getVipRoomList(roleId)
	local ec, roomList = context.callS2S(SERVICE.CATCH_FISH, "getVipRoomList")
	if ec ~= SystemError.success then
		return ec
	end
	return ec, {rooms = roomList}
end

------------------------------------------------------------------------------------
local function getArenaConf(type, level)
	for _, item in ipairs(arenaConfig) do
		if item.type == type and item.level == level then
			return item
		end
	end
end

function catchFishImpl.getArenaList(roleId)
	local ec, joinInfos = context.callS2S(SERVICE.CATCH_FISH, "getArenaList", roleId)
	return ec, joinInfos
end

function catchFishImpl.createArena(roleId, createInfo)
	createInfo.roomId = 0
	return catchFishImpl.joinArena(roleId, createInfo)
end

function catchFishImpl.joinArena(roleId, joinRequest)
	local conf = getArenaConf(joinRequest.type, joinRequest.level)
	if not conf then
		return SystemError.argument
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId)
	--检查报名条件
	if conf.bet.goodsId == roleConst.GOLD_ID then
		if roleInfo.gold < conf.bet.amount then
			return GameError.goldNotEnough
		end
	elseif conf.bet.goodsId == roleConst.TREASURE_ID then
		if roleInfo.treasure < conf.bet.amount then
			return GameError.treasureNotEnough
		end
	else
		return SystemError.config
	end

	if joinRequest.roomId > 0 then
		local arena = context.callS2S(SERVICE.CATCH_FISH, "getArena", joinRequest.roomId)
		if not arena then
			return CatchFishError.roomNotFound
		end
		if arena.isBegan then
			return CatchFishError.isInArena
		end
		if joinRequest.password ~= arena.password then
			return CatchFishError.passwordWrong
		end
	end

	local arena = context.callS2S(SERVICE.CATCH_FISH, "getJoinArena", roleId)
	if arena then
		if arena.isBegan then
			return CatchFishError.isInArena
		end
		if arena.roomId == joinRequest.roomId then
			return CatchFishError.joined
		else
			catchFishImpl.cancelJoinArena(roleId)
		end
	end

	local winRate = dbHelp.call("catchFish.getWinRate", roleId, joinRequest.level)

	local info = {
		roomId = joinRequest.roomId,
		type = joinRequest.type,
		level = joinRequest.level,
		password = joinRequest.password,
		roleId = roleId,
		nickname = roleInfo.nickname,
		avatar = roleInfo.avatar,
		winRate = winRate or 0,
	}

	local ec, roomId = context.callS2S(SERVICE.CATCH_FISH, "joinArena", info)
	if ec ~= SystemError.success then
		return ec
	end

	--扣除赌注
	local ec
	if conf.bet.goodsId == roleConst.GOLD_ID then
		ec = resOp.costGold(roleId, -conf.bet.amount, logConst.betCost)
	elseif conf.bet.goodsId == roleConst.TREASURE_ID then
		ec = resOp.costTreasure(roleId, -conf.bet.amount, logConst.betCost)
	else
		ec = SystemError.config
	end

	if ec ~= SystemError.success then
		return ec
	end

	return ec, roomId
end

function catchFishImpl.cancelJoinArena(roleId)
	--返还赌注
	local bet = dbHelp.call("catchFish.unfreezeBet", roleId)
	if bet then
		resOp.send(roleId, bet.goodsId, bet.amount, logConst.betReturn)
	end
	local ec = context.callS2S(SERVICE.CATCH_FISH, "cancelJoinArena", roleId)
	return ec
end

function catchFishImpl.enterArena(roleId, roomId)
	local info = {
		roomId = roomId,
		roleId = roleId,
	}
	local ec, catchFishSvc, roomInfo = context.callS2S(SERVICE.CATCH_FISH, "enterArena", info)
	if ec ~= SystemError.success then
		return ec
	end

	local gunLevel = roomInfo.minGunLevel
	for _, playerInfo in pairs(roomInfo.players) do
		if playerInfo.roleId == roleId then
			gunLevel = playerInfo.gunLevel
			break
		end
	end

	context.catchFishSvc = catchFishSvc
	curUsedGunInfo = {gunType = 1, gunLevel = gunLevel, fireTime = skynet.now()}
	isDoingArena = true
	isCrit = false

	--参加竞技场1此次，更新每日任务
	taskCtrl.incrTaskStep(roleId, TaskType.ArenaJoin, 1, roomInfo.level)

	return ec, roomInfo
end

function catchFishImpl.getArenaResults(roleId)
	local results = dbHelp.call("catchFish.getArenaResults", roleId)
	return SystemError.success, {items = results}
end

function catchFishImpl.getDoingArena(roleId)
	return context.callS2S(SERVICE.CATCH_FISH, "getDoingArena", roleId)
end

function catchFishImpl.giveUpArena(roleId, roomId)
	local ec, svc = context.callS2S(SERVICE.CATCH_FISH, "giveUpArena", roleId, roomId)
	if ec ~= SystemError.success then
		return ec
	end

	if context.catchFishSvc == svc then
		context.catchFishSvc = nil
	end

	return ec
end

function catchFishImpl.onLogin(roleId)
	context.callS2S(SERVICE.CATCH_FISH, "leave", roleId)
	
	--当服务器异常关闭时，应归还玩家赌注
	local bet = dbHelp.call("catchFish.getBet", roleId)
	if bet then
		dbHelp.call("catchFish.deleteBet", roleId)
		resOp.send(roleId, bet.goodsId, bet.amount, logConst.betReturn)
	end
end

function catchFishImpl.onLogout(roleId)
	context.sendS2S(SERVICE.CATCH_FISH, "cancelJoinArena", roleId)
	--向捕鱼服务发送玩家离开消息
	catchFishImpl.leaveRoom(roleId)
end

return catchFishImpl