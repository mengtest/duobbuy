local skynet = require("skynet")
local logger = require("log")
local context = require("common.context")
local dbHelp = require("common.db_help")
local roleConst = require("role.role_const")
local roleEvent = require("role.role_event")
local noviceConst = roleConst.novices
local configDb = require("config.config_db")
local materialConf = configDb.material
local noviceConf = configDb.novice_protection
local returnAwardConf = configDb.return_award_config
local randomResConf = configDb.random_resource
local RobotInfoConfig = configDb.robot_info
local LevelConfig = configDb.level_config
local GunLevelUnlockConfig = configDb.gun_level_unlock
local gunConf = configDb.gun
local globalConf = require("config.global")
local logConst = require("game.log_const")
local json = require("json")

local OneDaySec = 86400 -- 	一天的秒数
local OneHourSec = 3600	--	一小时的秒数
local OneMinSec = 60 	--	一分钟的秒数
local ReturnLogoutSec = os.time(roleConst.returnLogoutDate)

local roleCtrl = {}
local roleInfoCache = {}
local slowLogAttrs = {}
local accountInfo = {}
local timeFuncActiveFlag = {} -- 定时器有效标识

local MAX_FREE_NOT_FISH_GOLD = 20000	--最大免费初始资源

local recordGoldFlag = false
local loginTime

local NotAddStockLogType = {
	[logConst.dailyRechargeGet] = true,
	[logConst.roundRechargeGet] = true,
	[logConst.dailyTaskGet] = true,
	[logConst.chargeSend] = true,
	[logConst.treasureBowlGet] = true,
	[logConst.couponGet] = true,
	[logConst.chargeDiskGet] = true,
	[logConst.crazyBoxGet] = true,
	-- logConst.sevenDayLoginGet,  
	-- logConst.onlineAwardGet,
	-- logConst.signDayGet,
	-- logConst.signWeekGet,
	-- logConst.dailyTaskTotalGet,
	-- logConst.signDiskGet,
}

------------------------------------玩家夺宝卡日志入库closure------------------------------------------------------------

-- 记录夺宝卡消费
local function recordTreasureLog(roleId, amount, source)
	local roleInfo = roleInfoCache[roleId]
	if not roleInfo then
		return
	end
	source 	= source or logConst.unKnow
	if not source or source == logConst.unKnow then
		logger.Debugf("lose source", debug.traceback())
	end
	local logInfo = {
		roleId = roleId,
		changeVal = amount,
		source = source,
		curValue = roleInfo.treasure,
	}
	local date = os.date("%Y%m%d")
	logger.Game("treasure_log_"..date, logInfo)
end

------------------------------------玩家金币日志入库closure------------------------------------------------------------

-- 记录金币消耗
local function recordGoldLogFunc(countMax)
	local startSec, endSec
	local curAmount, count = 0, 0
	local stepInfo = {}
	local delimiter = ","

	local formatStepLog = function()
		local log = {}
		for flag,num in pairs(stepInfo) do
			log[#log+1] = flag .. delimiter .. num
		end
		return log
	end

	local record = function(roleId, curValue)
		if table.empty(stepInfo) then
			return
		end
		local logInfo = {
			roleId = roleId,
			changeVal = curAmount,
			curValue = curValue,
			startSec = startSec,
			endSec = endSec,
			stepInfo = formatStepLog(),
		}
		--dump(logInfo)
		local date = os.date("%Y%m%d")
		logger.Game("gold_log_"..date, logInfo)
	end

	local stepLog = function(source, amount)
		if source and amount then
			local flag = source .. delimiter .. amount
			stepInfo[flag] = (stepInfo[flag] or 0) + 1
		end
	end

	local func = function(roleId, amount, source, flag)
		local roleInfo = roleInfoCache[roleId]
		if not roleInfo then
			return
		end
		local amount = amount or 0
		if count == 0 and not flag then
			curAmount = amount
			startSec = skynet.time()
			endSec = startSec
			stepLog(source, amount)
			count = count + 1
		elseif flag then
			record(roleId, roleInfo.gold - amount)
			startSec = skynet.time()
			endSec = startSec
			curAmount = amount
			stepLog(source, amount)
			count = 0
		else
			count = count + 1
			curAmount = curAmount + amount
			endSec = skynet.time()
			stepLog(source, amount)
			if count >= countMax then
				record(roleId, roleInfo.gold)
				startSec = skynet.time()
				endSec = startSec
				stepInfo = {}
				count = 0
				curAmount = 0
			end
		end
	end
	return func
	
end
local recordGoldLog = recordGoldLogFunc(roleConst.logGoldNum)

------------------------------------金币子弹射击消耗和获得日志入库closure------------------------------------------------------------

-- 记录渔场内金币变化
local function recordGoldFishLogFunc(countMax, logSource)
	local startSec, endSec, curAmount
	local count = 0
	local logSource = logSource

	local record = function(roleId, stepVal)
		if not stepVal then
			return
		end
		local logInfo = {
			roleId = roleId,
			count = count,
			source = logSource,
			stepVal = stepVal,
			startSec = startSec,
			endSec = endSec,
			totalVal = stepVal * count,
		}
		--dump(logInfo)
		local date = os.date("%Y%m%d")
		logger.Game("fish_gold_log_"..date, logInfo)
	end

	local func = function(roleId, amount, flag)
		local roleInfo = roleInfoCache[roleId]
		if not roleInfo then
			return
		end
		local amount = amount or 0
		if not curAmount and not flag then
			curAmount = amount
			startSec = skynet.time()
			endSec = startSec
			count = count + 1
		elseif curAmount ~= amount or flag then
			record(roleId, curAmount)
			startSec = skynet.time()
			endSec = startSec
			curAmount = amount
			count = 1
		else
			count = count + 1
			endSec = skynet.time()
			if count >= countMax then
				record(roleId, curAmount)
				startSec = skynet.time()
				endSec = startSec
				count = 0
			end
		end
	end
	return func
end
--local recordGoldShotCostLog = recordGoldFishLogFunc(roleConst.logFishGoldNum, logConst.shotCost)
--local recordGoldShotGetLog = recordGoldFishLogFunc(roleConst.logFishGoldNum, logConst.shotGet)

------------------------------------玩家属性延迟入库closure----------------------------------------------------------

-- 延续玩家资源记录方法
local function slowAttrValRecordFunc(attrName, timeoutSec)
	slowLogAttrs[#slowLogAttrs+1] = attrName
	local flag = false
	local func = function(roleId)
		if flag then
			return
		end
		flag = true
		skynet.timeout(timeoutSec * 100, function()
			flag = false
			local roleInfo = roleCtrl.getRoleInfo(roleId)
			if roleInfo and roleInfo[attrName] then
				dbHelp.send("role.setAttrVal", roleId, attrName, roleInfo[attrName])
			end
		end)
	end
	return func
end
local recordGold = slowAttrValRecordFunc("gold", 10)
-- local recordStock = slowAttrValRecordFunc("stock", roleConst.recordGoldSec)
local recordFishTreasure = slowAttrValRecordFunc("fishTreasure", 10)
local recordTreasure = slowAttrValRecordFunc("treasure", 10)
-- local recordNotFishGold = slowAttrValRecordFunc("notFishGold", roleConst.recordGoldSec)
local recordExp = slowAttrValRecordFunc("exp", roleConst.recordGoldSec)
local recordLevel = slowAttrValRecordFunc("level", roleConst.recordGoldSec)
local recordCostGold = slowAttrValRecordFunc("costGold", roleConst.recordGoldSec)
local recordTotalCostGold = slowAttrValRecordFunc("totalCostGold", roleConst.recordGoldSec)
local reocrdGoldGunGoldCost = slowAttrValRecordFunc("goldGunGoldCost", roleConst.recordGoldSec)
local recordFrozenGunGoldCost = slowAttrValRecordFunc("frozenGoldCost", roleConst.recordGoldSec)
local recordCritGunGoldCost = slowAttrValRecordFunc("critGoldCost", roleConst.recordGoldSec)
local recordSliceGunGoldCost = slowAttrValRecordFunc("sliceGoldCost", roleConst.recordGoldSec)
-- local recordBackNotFishGold = slowAttrValRecordFunc("backNotFishGold", roleConst.recordGoldSec)
local recordGoldGunPrize = slowAttrValRecordFunc("goldGunPrize", roleConst.recordGoldSec)

------------------------------------------------------------------------------------------------

-- 获取玩家信息
function roleCtrl.getRoleInfo(roleId)
	local roleInfo = roleInfoCache[roleId]
	if not roleInfo then
		roleInfo = dbHelp.call("auth.getRoleInfo", roleId)
		if not roleInfo then
			logger.Error("roleInfo is nil, roleId:"..roleId)
		end

		roleInfo.originGuns = copy(roleInfo.guns)
		roleInfo.activityGuns = {}
		local gunAgeInfo = dbHelp.call("activity.getGunEndInfo", roleId)
		local curSec = os.time()
		for gunId in pairs(gunConf) do
			local gunEndTime = gunAgeInfo[tostring(gunId)]
			if gunEndTime and curSec < gunEndTime then
				if not table.find(roleInfo.guns, gunId) then
					roleInfo.guns[#roleInfo.guns+1] = gunId   -- 加入时限炮塔
					roleInfo.activityGuns[#roleInfo.activityGuns+1] = gunId  
					roleCtrl.handleGunAge(roleId, gunId, gunEndTime)  -- 处理自动过期
				end
			end
		end
		if not table.find(roleInfo.guns, roleInfo.gun) then
			roleInfo.gun = globalConf.ROLE_INIT_GUN
			dbHelp.send("role.setAttrVal", roleId, "gun", globalConf.ROLE_INIT_GUN)
		end
		if roleInfo.isEnergy and roleInfo.gun ~= roleConst.goldGunId then
			roleInfo.isEnergy = false
			dbHelp.send("role.setAttrVal", roleId, "isEnergy", false)
		end

		if not roleInfo.chargeNum then
			local chargeNum = context.callS2S(SERVICE.CHARGE, "getTotalPriceByTime", roleId)
			dbHelp.send("role.setAttrVal", roleId, "chargeNum", chargeNum)
			roleInfo.chargeNum = chargeNum
		end
		-- if not roleInfo.backNotFishGold then
		-- 	roleInfo.backNotFishGold = roleInfo.notFishGold
		-- 	dbHelp.send("role.setAttrVal", roleId, "backNotFishGold", roleInfo.backNotFishGold)
		-- end

		roleInfo.bag = roleInfo.bag or 0

		-- -- 修复玩家经验
		-- if not roleInfo.exp then 
		-- 	roleInfo.exp = 0
		-- end

		-- -- 修复玩家等级
		-- if not roleInfo.level then 
		-- 	roleInfo.level = 1
		-- 	-- 根据玩家总的消耗折算等级

		-- end

		-- -- 修复玩家炮倍
		-- if not roleInfo.unlockGunLevel then 
		-- 	roleInfo.unlockGunLevel = {}
		-- end

		roleInfoCache[roleId] = roleInfo
	end
	return roleInfo
end

-- 增加经验
function roleCtrl.addExp(roleId, exp)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if not roleInfo then return end 
	exp = math.abs(exp)

	-- 经验加成
	-- 炮台经验加成
	-- ...

	local level = roleInfo.level or 1
	exp = (roleInfo.exp or 0) + exp
	while true do
		local LevelVO = LevelConfig[level]
		if not LevelVO or exp < LevelVO.exp then 
			break
		end

		-- 下一级是否存在
		local nextLevel = level + 1
		if not LevelConfig[nextLevel] then 
			break
		end

		level = nextLevel
		exp = exp - LevelVO.exp
	end

	local roleExpInfo = {}
	if roleInfo.exp ~= exp then 
		roleInfo.exp = exp
		roleExpInfo.exp = exp
		recordExp(roleId)
	end
	if roleInfo.level ~= level then 
		roleInfo.level = level
		roleExpInfo.level = level
		recordLevel(roleId)
		
		-- send to cathFishSvc
		if context.catchFishSvc then
			context.sendS2S(context.catchFishSvc, "updateRoleInfo", roleId, {level = roleInfo.level})
		end
	end

	if table.empty(roleExpInfo) then 
		return
	end
		
	-- send to clinet
	-- dump(roleExpInfo)
	context.sendS2C(roleId, M_Role.handleExpInfoUpdate, roleExpInfo)
end

-- 获取资源数量
function roleCtrl.getResNum(roleId, goodsId)
	local goodsInfo = materialConf[goodsId]
	if not goodsInfo then
		return 0
	end
	local attrName = goodsInfo.attrName
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if not roleInfo[attrName] then
		return 0
	end
	return roleInfo[attrName]
end

-- 添加资源
function roleCtrl.addRes(roleId, goodsId, amount, source, price)
	assert(amount ~= nil, "roleId:"..roleId.." source:"..source)
	-- 添加经验
	if source == logConst.shotGet then 
		-- roleCtrl.addExp(roleId, amount)
	end

	local goodsInfo = materialConf[goodsId]
	if not goodsInfo then
		return GameError.resourceNotExist
	end
	local attrName = goodsInfo.attrName
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if not roleInfo[attrName] then
		return GameError.resourceNotExist
	end
	local attrVal = roleInfo[attrName] + amount
	if attrVal < 0 then
		if attrName == "gold" then
			return GameError.goldNotEnough
		elseif attrName == "treasure" then
			return GameError.treasureNotEnough
		else
			return GameError.resourceNotEnough
		end
	end

	if attrName == "treasure" then
		recordTreasure(roleId)
		context.sendS2C(roleId, M_Role.handleTreasureUpdate, attrVal)
		if source == logConst.shotGet or source == logConst.goldGunEngreyGet then
			roleInfo["fishTreasure"] = (roleInfo["fishTreasure"] or 0) + amount
			recordFishTreasure(roleId)
		end
		if source == logConst.fundCost then
			roleCtrl.setSecKillStatus(roleId, true)
		end
		if source ~= logConst.shotGet then
			dbHelp.send("role.setAttrVal", roleId, "treasure", attrVal)
		end
	elseif attrName == "gold" then
		recordGold(roleId)
		if source ~= logConst.shotCost and source ~= logConst.shotGet then
			context.sendS2C(roleId, M_Role.handleGoldUpdate, attrVal)
			if not NotAddStockLogType[source] then
				if source == logConst.chargeGet and price then
					roleCtrl.addChargeGold(roleId, amount, price)
				else
					-- 金币->有效金币转换系数
					local add = amount
					if amount > 0 and roleConst.NotFishGoldRatio[source] then 
						if roleInfo.isVip or roleInfo.chargeStatus then 
							add = amount * (roleConst.NotFishGoldRatio[source].vipRoleRatio or 1)
						else
							add = amount * (roleConst.NotFishGoldRatio[source].freeRoleRatio or 1)
						end
						logger.Infof("roleCtrl.addRes(roleId:%s, goodsId:%s, amount:%s, source:%s, price:%s) NotFishGoldRatio add:%s", roleId, goodsId, amount, source, price, add)
					end

					-- 免费玩家有效金币上限控制
					if add > 0 and not roleInfo.isVip and not roleInfo.chargeStatus then
						add = math.min(add, MAX_FREE_NOT_FISH_GOLD - roleInfo.notFishGold)
					end
					if add ~= 0 then
						roleCtrl.addNotFishGold(roleId, add)
					end
				end
				if source == logConst.dailyFreeGold then
					roleCtrl.setChargeStatus(roleId, false)
				end
			end
		elseif source == logConst.shotCost then
			--记录玩家总消耗
			roleInfo["totalCostGold"] = (roleInfo["totalCostGold"] or 0) + math.abs(amount)
			recordTotalCostGold(roleId)
			-- 记录不同炮倍消耗
			--recordGoldShotCostLog(roleId, amount)
			-- 记录黄金能量
			roleCtrl.addGoldGunEnergy(roleId, math.abs(amount))
		end
		
		if source == logConst.boxCost then			
			dbHelp.send("role.setAttrVal", roleId, "gold", attrVal)
		end

		if context.catchFishSvc then
			local exclude = true
			if source ~= logConst.dailyDiskFree and source ~= logConst.chargeDiskGet then
				exclude = false
			end
			context.sendS2S(context.catchFishSvc, "updateGold", roleId, attrVal, exclude)
		end
	elseif attrName == "bag" then
		roleCtrl.recordBag(roleId, attrVal)
	end

	roleInfo[attrName] = attrVal

	if attrName == "treasure" then
		recordTreasureLog(roleId, amount, source)
	elseif attrName == "gold" then
		recordGoldLog(roleId, amount, source)
	end

	--context.sendS2S(SERVICE.STATISTIC, "statisticIncrement", attrName, amount)
	roleEvent.dispathResChangeEvent(roleId, goodsId, amount, source)

	return SystemError.success
end

-- 添加大炮
function roleCtrl.addGun(roleId, gunId, source, liveTime)
	local gunInfo = gunConf[gunId]
	if not gunInfo then
		return GameError.resourceNotExist
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId)

	if not table.find(roleInfo.guns, gunId) then
		roleInfo.guns[#roleInfo.guns+1] = gunId
		if liveTime then
			roleInfo.activityGuns[#roleInfo.activityGuns+1] = gunId
			local endSec = os.time()+liveTime
			dbHelp.send("activity.setGunEndTime", roleId, gunId, endSec)
			roleCtrl.handleGunAge(roleId, gunId, endSec)
			context.sendS2C(roleId, M_Role.handleGetActivityGun, {gunId = gunId, endSec = endSec})
		else
			roleInfo.originGuns[#roleInfo.originGuns+1] = gunId
			dbHelp.send("role.setAttrVal", roleId, "guns", roleInfo.originGuns)
		end
	else
		local isActivityGun = table.find(roleInfo.activityGuns, gunId)
		if liveTime and isActivityGun then
			local gunAgeInfo = dbHelp.call("activity.getGunEndInfo", roleId)
			local gunEndTime = gunAgeInfo[tostring(gunId)]
			dbHelp.send("activity.incrGunEndTime", roleId, gunId, liveTime)
			local endSec = gunEndTime + liveTime
			roleCtrl.handleGunAge(roleId, gunId, endSec)
			context.sendS2C(roleId, M_Role.handleGetActivityGun, {gunId = gunId, endSec = endSec})
		elseif not liveTime and not isActivityGun then
			return SystemError.success
		elseif not liveTime and isActivityGun then
			table.removeItem(roleInfo.activityGuns, gunId, true)
			roleInfo.originGuns[#roleInfo.originGuns+1] = gunId
			dbHelp.send("role.setAttrVal", roleId, "guns", roleInfo.originGuns)
			context.sendS2C(roleId, M_Role.handleGetActivityGun, {gunId = gunId, endSec = -1})
		elseif liveTime and not isActivityGun then
			return SystemError.success
		end
	end

	-- if gunId == roleConst.goldGunId then
	-- 	if not roleInfo.isEnergy then
	-- 		roleInfo["isEnergy"] = true
	-- 		dbHelp.send("role.setAttrVal", roleId, "isEnergy", true)
	-- 		context.sendS2C(roleId, M_Role.handleGetGoldGun)
	-- 	end
	-- 	if not roleInfo.goldGunGoldCost then
	-- 		roleInfo.goldGunGoldCost = 0
	-- 		reocrdGoldGunGoldCost(roleId)
	-- 	end
	-- end

	return SystemError.success
end

function roleCtrl.updateGun(roleId, gunId)
	local gunInfo = gunConf[gunId]
	if not gunInfo then
		return GameError.resourceNotExist
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId)
	
	if not table.find(roleInfo.guns, gunId) then
		return GameError.resourceNotExist
	end
	roleInfo.gun = gunId
	dbHelp.send("role.setAttrVal", roleId, "gun", gunId)
	if gunId == roleConst.goldGunId then
		if not roleInfo.isEnergy then
			roleInfo["isEnergy"] = true
			dbHelp.send("role.setAttrVal", roleId, "isEnergy", true)
			context.sendS2C(roleId, M_Role.handleGetGoldGun)
		end
		if not roleInfo.goldGunGoldCost then
			roleInfo.goldGunGoldCost = 0
			reocrdGoldGunGoldCost(roleId)
		end
	else
		roleInfo.isEnergy = false
		dbHelp.send("role.setAttrVal", roleId, "isEnergy", false)
	end
	return SystemError.success
end

-- 记录夺宝卡
function roleCtrl.recordTreasure(roleId, attrVal)
	dbHelp.send("role.setAttrVal", roleId, "treasure", attrVal)
	context.sendS2C(roleId, M_Role.handleTreasureUpdate, attrVal)
end

-- 记录福袋
function roleCtrl.recordBag(roleId, attrVal)
	dbHelp.send("role.setAttrVal", roleId, "bag", attrVal)
	context.sendS2C(roleId, M_LuckyBag.handleBagNumUpdate, attrVal)
end

local channels = {
	-- [3] = true,
	-- [2000002] = true,
	-- [2000005] = true,
	-- [2000006] = true,
	-- [203] = true,
}
function roleCtrl.addChargeGold(roleId, amount, price)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if not roleInfo.channelId or not channels[roleInfo.channelId] then
		return roleCtrl.addNotFishGold(roleId, amount)
	end
	local curAwardRate = roleInfo.gold / 6000 + (roleInfo.fishTreasure or 0)
	local supposeAwardRate = (roleInfo.backNotFishGold or 0) / 6000
	local awardRate = curAwardRate / supposeAwardRate
	local xVal = awardRate / (awardRate + 1)
	local xMax = 10000
	local xLuckyNum = math.floor(xMax * xVal)
	local randNum = math.rand(1, xMax)

	local startNum = 0
	local min, max = 1, 1
	local chargeNum = roleInfo.chargeNum
	for _,conf in ipairs(randomResConf) do
		if price == conf.recharge then
			if chargeNum >= startNum and chargeNum < conf.accumulate then
				min, max = conf.min, conf.max
				break
			end
			startNum = conf.accumulate
		end
	end

	local realNovice
	if randNum <= xLuckyNum then
		realNovice = math.rand( math.floor(min*amount), math.floor((min + max)/2*amount))
	else
		realNovice = math.rand( math.floor((min + max)/2*amount), math.floor(max*amount))
	end

	roleCtrl.addNotFishGold(roleId, math.floor(realNovice), _, amount)
end

-- 设置notFishGold
function roleCtrl.addNotFishGold(roleId, amount, notSync, backAmount)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo["notFishGold"] = (roleInfo["notFishGold"] or 0) + amount
	if roleInfo["notFishGold"] < 0 then
		roleInfo["notFishGold"] = 0
	end
	-- if not backAmount then
	-- 	backAmount = amount
	-- end
	-- roleInfo["backNotFishGold"] = (roleInfo["backNotFishGold"] or 0) + backAmount
	if context.catchFishSvc and not notSync then
		local noviceNum = roleInfo["novice"] or 0
		local chargeStatus = roleInfo["chargeStatus"] or false
		context.sendS2S(context.catchFishSvc, "updateNotFishGold", roleId, roleInfo["notFishGold"], noviceNum, chargeStatus)
	end

	dbHelp.send("role.setAttrVal", roleId, "notFishGold", roleInfo["notFishGold"])
	-- recordNotFishGold(roleId)
	-- recordBackNotFishGold(roleId)
end

-- 设置充值状态
function roleCtrl.setVip(roleId)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if not roleInfo.isVip then
		roleInfo.isVip = true
		dbHelp.send("role.setAttrVal", roleId, "isVip", true)
		if context.catchFishSvc then
			context.sendS2S(context.catchFishSvc, "updateVip", roleId, true)
		end
	end
end

-- 获取玩家前端信息
function roleCtrl.getRoleInfoByView(roleId)
	local roleInfo = roleCtrl.getRoleInfo(roleId)

	local activityGuns = roleInfo.activityGuns
	local endGuns = {}
	for _, gunId in pairs(activityGuns) do
		local endSec = timeFuncActiveFlag[gunId]
		endGuns[#endGuns+1] = {gunId = gunId, endSec = endSec}
	end

	local data = {
		nickname = roleInfo.nickname,
		avatar = roleInfo.avatar,
		gold = roleInfo.gold,
		gun = roleInfo.gun,
		guns = roleInfo.guns,
		treasure = roleInfo.treasure,
		gunLevel = roleInfo.gunLevel,
		mobileNum = roleInfo.mobileNum,
		isEnergy = roleInfo.isEnergy and true or false,
		goldGunGoldCost = roleInfo.goldGunGoldCost,
		goldEnergyStep = roleConst.goldEnergyStep,
		goldGunTreauser = roleInfo.goldGunTreauser,
		chargeNum = roleInfo.chargeNum,
		endGuns = endGuns,
		frozenGoldCost = roleInfo.frozenGoldCost,
		frozenGoldMax = roleConst.frozenEnergyMax,
		critGoldCost = roleInfo.critGoldCost,
		critGoldMax = roleConst.critEnergyMax,
		sliceGoldCost = roleInfo.sliceGoldCost,
		sliceGoldMax = roleConst.sliceEnergyMax,
	}
	return SystemError.success, data
end

-- 获取免费金币领取剩余时间
function roleCtrl.getFreeGoldInfo(roleId)
	local freeGoldInfo = dbHelp.call("role.getFreeGoldInfo", roleId)
	if freeGoldInfo then
		local timeSec = os.time()
		if freeGoldInfo.endTime and freeGoldInfo.endTime < timeSec then
			roleCtrl.setFreeGoldInfo(roleId)
			return SystemError.success, 0
		end
		if freeGoldInfo.joinNum and freeGoldInfo.joinNum >= roleConst.freeGoldTime then
			return RoleError.freeGoldNumMax
		end
		local endTime = math.min(freeGoldInfo.endTime, freeGoldInfo.nextTime)
		local leftSec = endTime - timeSec
		leftSec = leftSec > 0 and leftSec or 0
		return SystemError.success, leftSec
	else
		roleCtrl.setFreeGoldInfo(roleId)
		return SystemError.success, 0
	end	
end

-- 设置免费金币领取信息
function roleCtrl.setFreeGoldInfo(roleId)
	local sec = os.time()
	local dayEndTime = roleCtrl.getDayEndTime(sec)
	local nextFreeTime = sec
	dbHelp.send("role.setFreeGoldInfo", roleId, nextFreeTime, dayEndTime)
end

-- 获取免费金币
function roleCtrl.getFreeGold(roleId)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if not roleInfo.mobileNum then
		return RoleError.mobileNotLock
	end
	if roleInfo.gold >= roleConst.freeGoldMax then
		return RoleError.freeGoldZero
	end
	local addAmount = roleConst.freeGoldMax - roleInfo.gold
	local ec, leftSec = roleCtrl.getFreeGoldInfo(roleId)
	if ec ~= SystemError.success then
		return ec
	end
	if leftSec == 0 then
		dbHelp.send("role.incrFreeGoldJoinNum", roleId, roleConst.freeGoldSec+os.time())
		
		local ec = roleCtrl.addRes(roleId, roleConst.GOLD_ID, addAmount, logConst.dailyFreeGold)

		if noviceConst.dailyFree and noviceConf[noviceConst.dailyFree] then
			local noviceNum = noviceConf[noviceConst.dailyFree].num
			roleCtrl.setNovice(roleId, noviceNum)
		end

		return ec, addAmount
	else
		return RoleError.freeGoldTimeLeft
	end
end

-- 获取首冲状态
function roleCtrl.getFirstChargeInfo(roleId)
	local flag = context.callS2S(SERVICE.CHARGE, "isUseJoinType", roleId)
	return flag and 1 or 0
end

-- 获取今天截至时间
function roleCtrl.getDayEndTime(sec)
	sec = sec or os.time()
	local timeDate = os.date("*t", sec)
	local dayEndTime = sec + OneDaySec - (timeDate.hour * OneHourSec + timeDate.min * OneMinSec + timeDate.sec)
	return dayEndTime
end

-- 设置玩家信息
function roleCtrl.changeRoleInfo(roleId, data)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if data.nickname and data.nickname ~= roleInfo.nickname then
	    -- if dbHelp.call("auth.getRoleIdByNickname", data.nickname) then
	    --     return AuthError.nicknameIsExists
	    -- end
	    -- if dbHelp.call("auth.getRobotByNickname", data.nickname) then
	    -- 	return AuthError.nicknameIsExists
	    -- end
		local ret = context.callS2S(SERVICE.AUTH, "changeNickName", roleInfo.nickname, data.nickname)
		if ret ~= SystemError.success then 
			return ret 
		end 
	end
	for attrName, attrVal in pairs(data) do
		roleInfo[attrName] = attrVal
		dbHelp.send("role.setAttrVal", roleId, attrName, attrVal)
		if attrName == "nickname" then
			context.callS2S(SERVICE.RANK, "changeName", roleId, attrVal)
		end
	end
	return SystemError.success
end

-- 保存前端设置
function roleCtrl.saveSeting(roleId, data)
	local info = data.data
	if info then
		dbHelp.send("role.setSeting", roleId, info)
	end
	return SystemError.success
end

-- 获取前端设置
function roleCtrl.getSeting(roleId)
	local info = dbHelp.call("role.getSeting", roleId)
	return info or "{}"
end

-- 商城测试接口
function roleCtrl.shopTest(roleId, shopIndex)
	context.callS2S(SERVICE.CHARGE, "deBugBuyItem", roleId, shopIndex)
	return SystemError.success
end

-- 黄金能量兑换夺宝卡
function roleCtrl.useGoldEnergy(roleId)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if not roleInfo.isEnergy then
		return RoleError.noGoldEnergy
	end
	if not roleInfo.goldGunTreauser or roleInfo.goldGunTreauser < 1 then
		return RoleError.goldEnergyTooLow
	end
	roleCtrl.addRes(roleId, roleConst.TREASURE_ID, roleInfo.goldGunTreauser, logConst.goldGunEngreyGet)
	roleInfo.goldGunTreauser = 0
	dbHelp.send("role.setAttrVal", roleId, "goldGunTreauser", roleInfo.goldGunTreauser)
	return SystemError.success
end

--------------------------------------------------------------

-- 记录stock
function roleCtrl.addStock(roleId, amount)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo["stock"] = (roleInfo["stock"] or 0) + amount
	recordStock(roleId)
	return roleInfo["stock"]
end

----------------------------------------------------------------

-- 绑定手机
function roleCtrl.lockMobile(roleId, mobileNum)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo.mobileNum = mobileNum
	dbHelp.send("role.setAttrVal", roleId, "mobileNum", mobileNum)
	return SystemError.success
end

--------------------------------------------------------------

-- 记录novice
function roleCtrl.setNovice(roleId, amount)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo["novice"] = amount
	dbHelp.send("role.setAttrVal", roleId, "novice", amount)

	roleCtrl.addNotFishGold(roleId, 0)
	return SystemError.success
end

-----------------------------------------------------------------

-- 虚拟夺宝卡
function roleCtrl.setVirtualTreasure(roleId, amount)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo["virtualTreasure"] = amount
	dbHelp.send("role.setAttrVal", roleId, "virtualTreasure", amount)
	return SystemError.success
end

-- 设置是否充值状态
function roleCtrl.setChargeStatus(roleId, status)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo["chargeStatus"] = status
	dbHelp.send("role.setAttrVal", roleId, "chargeStatus", status)
	roleCtrl.addNotFishGold(roleId, 0)
	return SystemError.success
end

-- 设置是否参与夺宝
function roleCtrl.setSecKillStatus(roleId, status)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo["secKillStatus"] = status
	dbHelp.send("role.setAttrVal", roleId, "secKillStatus", status)
	return SystemError.success
end

-- 获取是否参与夺宝
function roleCtrl.getFundJoinsStatus(roleId)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if roleInfo.secKillStatus then
		return true
	end
	return false
end

-- 添加黄金能量槽
function roleCtrl.addGoldGunEnergy(roleId, amount)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if not roleInfo.isEnergy then
		return
	end
	roleInfo.goldGunGoldCost = (roleInfo.goldGunGoldCost or 0) + amount
	if roleInfo.goldGunGoldCost >= roleConst.goldEnergyStep then
		local goldGunTreauser = math.floor(roleInfo.goldGunGoldCost / roleConst.goldEnergyStep)
		roleInfo.goldGunGoldCost = roleInfo.goldGunGoldCost - goldGunTreauser * roleConst.goldEnergyStep
		roleInfo.goldGunTreauser = (roleInfo.goldGunTreauser or 0) + goldGunTreauser
		dbHelp.send("role.setAttrVal", roleId, "goldGunTreauser", roleInfo.goldGunTreauser)
	end
	reocrdGoldGunGoldCost(roleId)
	return SystemError.success
end

-- 获取换包奖励
function roleCtrl.getChangeBagAward(roleId, version)
	local status = roleCtrl.getChangeBagStatus(roleId, version)
	if status then
		dbHelp.send("role.recordChangeBag", roleId)
		roleCtrl.addRes(roleId, roleConst.GOLD_ID, roleConst.bagChangeGold, logConst.bagChangeGet)
		return SystemError.success
	end
	return RoleError.noChangeBag
end

-- 获取是否有换包奖励
function roleCtrl.getChangeBagStatus(roleId, version)
	if version < roleConst.bagChangeVersion then return false end
	local seting = roleCtrl.getSeting(roleId)
	local info = json.decode(seting)
	if info.downloaded then
		local record = dbHelp.call("role.isAwardBagChange", roleId)
		if record then
			return false
		else
			return true
		end
	else
		return false
	end
end

-- 添加充值金额
function roleCtrl.addChargeNum(roleId, amount)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo.chargeNum = roleInfo.chargeNum + amount
	dbHelp.send("role.incrAttrVal", roleId, "chargeNum", amount)
	context.sendS2C(roleId, M_Role.handleChargeNumUpdate, roleInfo.chargeNum)
	roleEvent.dispathChargeEvent(roleId)
	return SystemError.success
end

function roleCtrl.setCostGold(roleId, costGold)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if roleInfo.costGold and roleInfo.costGold == costGold then 
		return 
	end
	roleInfo.costGold = costGold
	recordCostGold(roleId)	
end 

-- 炮塔到期
function roleCtrl.handleGunAge(roleId, gunId, endSec)
	timeFuncActiveFlag[gunId] = endSec
	local leftSec = endSec - os.time()
	skynet.timeout(leftSec * 100, function()
		if timeFuncActiveFlag[gunId] ~= endSec then
			return
		end
		local roleInfo = roleCtrl.getRoleInfo(roleId)
		if not table.find(roleInfo.activityGuns, gunId) then
			return
		end
		table.removeItem(roleInfo.activityGuns, gunId, true)
		table.removeItem(roleInfo.guns, gunId, true)
		if roleInfo.gun == gunId then
			roleInfo.gun = globalConf.ROLE_INIT_GUN
			dbHelp.send("role.setAttrVal", roleId, "gun", globalConf.ROLE_INIT_GUN)
		end
		if gunId == roleConst.goldGunId then
			roleInfo.isEnergy = false
			dbHelp.send("role.setAttrVal", roleId, "isEnergy", false)
		end
		context.sendS2C(roleId, M_Role.handleActivityGunEnd, gunId)
	end)
end

-- 添加冰冻炮能量
function roleCtrl.addFrozenGunCost(roleId, amount)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo.frozenGoldCost = (roleInfo.frozenGoldCost or 0) + amount
	if roleInfo.frozenGoldCost < 0 then
		roleInfo.frozenGoldCost = 0
	end
	if roleInfo.frozenGoldCost > roleConst.frozenEnergyMax then
		roleInfo.frozenGoldCost = roleConst.frozenEnergyMax
	end
	recordFrozenGunGoldCost(roleId)
	return SystemError.success
end

-- 清除冰冻炮能量
function roleCtrl.clearFrozenGunCost(roleId)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo.frozenGoldCost = 0
	recordFrozenGunGoldCost(roleId)
	return SystemError.success
end

-- 添加狂暴炮能量
function roleCtrl.addCritGunCost(roleId, amount)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo.critGoldCost = (roleInfo.critGoldCost or 0) + amount
	if roleInfo.critGoldCost < 0 then
		roleInfo.critGoldCost = 0
	end
	if roleInfo.critGoldCost > roleConst.critEnergyMax then
		roleInfo.critGoldCost = roleConst.critEnergyMax
	end
	recordCritGunGoldCost(roleId)
	return SystemError.success
end

-- 清除狂暴炮能量
function roleCtrl.clearCritGunCost(roleId)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo.critGoldCost = 0
	recordCritGunGoldCost(roleId)
	return SystemError.success
end

-- 添加切鱼炮能量
function roleCtrl.addSliceGunCost(roleId, amount)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo.sliceGoldCost = (roleInfo.sliceGoldCost or 0) + amount
	if roleInfo.sliceGoldCost < 0 then
		roleInfo.sliceGoldCost = 0
	end
	if roleInfo.sliceGoldCost > roleConst.sliceEnergyMax then
		roleInfo.sliceGoldCost = roleConst.sliceEnergyMax
	end
	recordSliceGunGoldCost(roleId)
	return SystemError.success
end

-- 清除切鱼炮能量
function roleCtrl.clearSliceGunCost(roleId)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo.sliceGoldCost = 0
	recordSliceGunGoldCost(roleId)
	return SystemError.success
end


-- 获取回归奖励状态
function roleCtrl.getReturnStatus(roleId)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	local curIndex = 0
	if roleInfo.logoutTime and roleInfo.logoutTime <= ReturnLogoutSec then
		local record = dbHelp.call("role.isAwardReturn", roleId)
		if not record then
			local startNum = 0
			local chargeNum = roleInfo.chargeNum
			if chargeNum > returnAwardConf[#returnAwardConf].recharge then
				curIndex = #returnAwardConf
			else
				for index,conf in ipairs(returnAwardConf) do
					if chargeNum > startNum and chargeNum <= conf.recharge then
						curIndex = index
					end
					startNum = conf.recharge
				end
			end
		end
	end
	return curIndex
end

-- 领取回归奖励
function roleCtrl.getReturnAward(roleId)
	local awardIndex = roleCtrl.getReturnStatus(roleId)
	if awardIndex <= 0 then
		return
	end
	local awardConfig = returnAwardConf[awardIndex]
	if not awardConfig then
		return
	end
	local award = awardConfig.award
	dbHelp.send("role.recordReturnAward", roleId, awardIndex)
	for _,info in pairs(award) do
		if info.goodsId then
			roleCtrl.addRes(roleId, info.goodsId, info.amount, logConst.returnAwardGet)
		elseif info.gunId then
			roleCtrl.addGun(roleId, info.gunId, logConst.returnAwardGet, info.time)
		end
	end
	return SystemError.success
end

function roleCtrl.getWeChatFollowStatus(roleId)
	local curDay = os.date("%Y%m%d")
	local record = dbHelp.call("role.getWeChatFollowStatus", roleId)
	local status = roleConst.weChatFollowStatus.show
	if record and record.showDay >= curDay then
		status = roleConst.weChatFollowStatus.hide
	end
	return SystemError.success, status
end

function roleCtrl.setWeChatFollowStatus(roleId)
	local curDay = os.date("%Y%m%d")
	dbHelp.send("role.setWeChatFollowStatus", roleId, curDay)
	return SystemError.success
end

--添加彩金炮彩金
function roleCtrl.addGoldGunPrize(roleId, amount)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	roleInfo.goldGunPrize = (roleInfo.goldGunPrize or 0) + amount
	recordGoldGunPrize(roleId)
	context.sendS2C(roleId, M_Role.handlePrizeUpdate, math.floor(roleInfo.goldGunPrize))
	return SystemError.success
end

----------------------------------------------------------------

function roleCtrl.loadOver(roleId)
	roleEvent.dispathLoadOverEvent(roleId)
end

-----------------------------------------------------------

function roleCtrl.onLoginBegin(roleId, accountdata)
	loginTime = os.time()
	dbHelp.send("auth.setLastLoginTime", roleId, loginTime)
	context.sendS2S(SERVICE.PUSH, "delLogoutRole", roleId)

	accountInfo = accountdata
	logger.Infof("roleCtrl.onLoginBegin roleId:%s accountdata:%s", roleId, dumpString(accountdata))
end

function roleCtrl.getAccountInfo(roleId)
	return accountInfo or {}
end

-- 获得当前在线时间
function roleCtrl.getOnlineSecs(roleId)
	if not loginTime then
		return
	end

	local onlineSec = dbHelp.call("role.getAttrVal", roleId, "onlineSec")
	if not onlineSec then
		return
	end

	onlineSec = onlineSec + (os.time() - loginTime)
	return onlineSec
end

function roleCtrl.onLogout(roleId)
	local roleInfo = roleInfoCache[roleId]
	if roleInfo then
		for _, attrName in ipairs(slowLogAttrs) do
			if roleInfo[attrName] then
				dbHelp.send("role.setAttrVal", roleId, attrName, roleInfo[attrName])
			end
		end

		local logoutTime = os.time()
		dbHelp.send("auth.setLastLogoutInfo", roleId, {logoutTime = logoutTime})
		if logoutTime - loginTime > 0 then
			dbHelp.send("role.incrOnlineSec", roleId, logoutTime - loginTime)
		end
		context.sendS2S(SERVICE.RECORD, "recordUpdateUserLoginInfo", {accounts = roleInfo.uid, onlineSecs = logoutTime - loginTime, channelId = roleInfo.channelId, pid = roleInfo.pid})
		recordGoldLog(roleId, nil, nil, true)
		--recordGoldShotCostLog(roleId, nil, true)
		--recordGoldShotGetLog(roleId, nil, true)
		-- context.sendS2S(SERVICE.PUSH, "addLogoutRole", roleId)
	end
end

return roleCtrl