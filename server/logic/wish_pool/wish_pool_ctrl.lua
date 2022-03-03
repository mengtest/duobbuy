local WishPoolCtrl = {}
local WishPoolConst = require("wish_pool.wish_pool_const")
local context = require('common.context')
local dbHelp = require("common.db_help")
local configDb = require("config.config_db")
local wishWellConfig = configDb.wish_well_config
local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityConst = require("activity.activity_const")
local activityTimeConst = activityConst.activityTime
local roleCtrl = require("role.role_ctrl")
local roleConst = require("role.role_const")
local logConst = require("game.log_const")
local activityStatus = require("activity.activity_const").activityStatus
local resCtrl = require("common.res_operate")

-- --重置许愿池奖品的数量信息
-- local function resetWishPoolAward(round)
-- 	local infos = {}
-- 	for id, conf in pairs(wishWellConfig) do
-- 		infos[#infos + 1] = {
-- 			awardId = conf.id,
-- 			num     = conf.num,
-- 		}
-- 	end
-- 	dbHelp.send("wishPool.resetInfo", round, infos)
-- end

-- --按照权重抽取奖品
-- local function randAward(roleId, round)
-- 	local totalWeight = 0
-- 	local weightArr = {}
-- 	local leftAwardNum = dbHelp.call("wishPool.getNumInfo", round)
-- 	if leftAwardNum <= 0 then 
-- 		resetWishPoolAward(round)
-- 	end 
-- 	local infos = dbHelp.call("wishPool.getInfo", round, _, {id = 1})
-- 	for id,info in pairs(infos) do
-- 		totalWeight = totalWeight + info.num
-- 		weightArr[id] = totalWeight
-- 	end

-- 	local randWeight = math.rand(1, totalWeight)
-- 	local randInfo 
-- 	for id, weight in ipairs(weightArr) do
-- 		if randWeight <= weight then
-- 			randInfo = infos[id]
-- 			randInfo.award = wishWellConfig[infos[id].awardId].award
-- 			break
-- 		end
-- 	end
-- 	return randInfo
-- end


-- --初始化许愿池的奖励信息
-- local function initWishPoolAward(round)
-- 	local infos = {}
-- 	for id, conf in pairs(wishWellConfig) do
-- 		infos[#infos + 1] = {
-- 			awardId = conf.id,
-- 			content = conf.content,
-- 			display = conf.display,
-- 			num     = conf.num,
-- 			round   = round,
-- 			type    = conf.type,
-- 			notice  = conf.notice
-- 		}
-- 	end
-- 	dbHelp.send("wishPool.initInfo", infos)
-- end


-- --判断当前是第几期,如果尚未有最新一期的记录,则初始化最新一期的奖品信息
-- local function judgeRoundInfo()
-- 	local sec = os.time()
-- 	local activityInfo = activityTimeCtrl.getActivityTime(activityTimeConst.wishPool)
-- 	if activityInfo then
-- 		if activityInfo.status ~= activityStatus.open then
-- 			return false
-- 		end
-- 		local flag = (sec >= activityInfo.sTime and sec <= activityInfo.eTime)
-- 		if not flag then 
-- 			return false
-- 		else
-- 			local round = activityInfo.round
-- 			local roundExistFlag = dbHelp.call("wishPool.judgeRoundExists",round)
-- 			if not roundExistFlag then
-- 				initWishPoolAward(round)
-- 			end
-- 			return flag, round
-- 		end
-- 	else
-- 		return false
-- 	end
-- end

-- function WishPoolCtrl.costRes(roleId, num)
-- 	local treasureCost = WishPoolConst.singleWishTreasureCost * num
-- 	local ec = resCtrl.costTreasure(roleId, treasureCost, logConst.wishPoolCost)
-- 	return ec
-- end

-- --获取许愿池界面信息
-- function WishPoolCtrl.getInfo(roleId)
-- 	local flag, round = judgeRoundInfo()
-- 	if not flag then
-- 		return ActivityError.notOpen
-- 	end
-- 	local result = {leftAwardNum = 0, displayInfo = {}, maxAwardNum = WishPoolConst.initAwardNum}
-- 	result.leftAwardNum = dbHelp.call("wishPool.getNumInfo", round)
-- 	if result.leftAwardNum <= 0 then 
-- 		resetWishPoolAward(round)
-- 		result.leftAwardNum = WishPoolConst.initAwardNum
-- 	end      
-- 	local displayInfo = dbHelp.call("wishPool.getInfo", round, {["$gt"] = 0}, {display=1})   --获取展示奖励的数量信息
-- 	for k, info in pairs(displayInfo) do
-- 		result.displayInfo[k] = {id = info.awardId, num = info.num}
-- 	end
-- 	return SystemError.success, result
-- end

-- --许愿池许愿
-- function WishPoolCtrl.makeWish(roleId, num)
-- 	if num ~= WishPoolConst.wishNumType.once and num ~= WishPoolConst.wishNumType.ten then
-- 		return SystemError.argument
-- 	end

-- 	local flag, round = judgeRoundInfo()
-- 	if not flag then
-- 		return ActivityError.notOpen
-- 	end
-- 	if num == WishPoolConst.wishNumType.ten then
-- 		local leftAwardNum = dbHelp.call("wishPool.getNumInfo", round)
-- 		if leftAwardNum < num then return WishPoolError.overLeftNum end 
-- 	end
-- 	local ec = WishPoolCtrl.costRes(roleId, num)
-- 	if ec ~= SystemError.success then 
-- 		return ec
-- 	end
-- 	local roleInfo = roleCtrl.getRoleInfo(roleId)

-- 	local awards = {}	   --要返回到前端的奖品id列
-- 	local goodsList = {}   --要发放的奖品
-- 	for i = 1,num do
-- 		local randInfo = randAward(roleId, round)
-- 		local awardInfo = randInfo.award or {}
-- 		local sendStatus = WishPoolConst.sendStatus.inHandle
-- 		if awardInfo.gunId or awardInfo.goodsId then
-- 			table.insert(goodsList,awardInfo)
-- 			sendStatus = WishPoolConst.sendStatus.done
-- 		end
-- 		awards[#awards+1] = randInfo.awardId

-- 		local record = {
-- 			goodsType = randInfo.type,
-- 			showFlag = (randInfo.display == 1),
-- 			goodsName = randInfo.content,
-- 			nickname = roleInfo.nickname,
-- 			prizeId = awardInfo.prizeId,
-- 			status = sendStatus,
-- 			round  = round,
-- 		}

-- 		dbHelp.call("wishPool.addRecord", roleId, record)
-- 		dbHelp.send("wishPool.incryInfo", randInfo.awardId, round, -1)
-- 		if randInfo.notice == 1 then
-- 			context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 12, words = {roleInfo.nickname, randInfo.content}})
-- 		end
-- 	end
-- 	local ec = resCtrl.sendList(roleId, goodsList, logConst.wishPoolGet)
-- 	if ec ~= SystemError.success then return ec end

-- 	return SystemError.success, awards
-- end

function WishPoolCtrl.getInfo(roleId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.wishPool)
	if not flag then
		return ActivityError.notOpen
	end

	local info = context.callS2S(SERVICE.ACTIVITY, "getWishPoolInfo", round)
	local wishWellInfo = info.wishWellInfo
	local leftNum = info.leftNum
	local displayInfo = {}
	for _,v in pairs(wishWellInfo) do
		local display = wishWellConfig[v.awardId].display
		if display > 0 then
			table.insert(displayInfo, {id = v.awardId, num = v.num})
		end
	end

	local result = {}
	result.leftAwardNum = leftNum
	result.maxAwardNum = WishPoolConst.initAwardNum
	result.displayInfo = displayInfo
	-- print("result",tableToString(result))
	return SystemError.success, result
end

function WishPoolCtrl.makeWish(roleId, num)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.wishPool)
	if not flag then
		return ActivityError.notOpen
	end

	local cost = WishPoolConst.singleWishTreasureCost * num
	local ec = resCtrl.isResEnough(roleId, roleConst.TREASURE_ID, cost)
	if ec ~= SystemError.success then
		return ec
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId)

	local ec, awards = context.callS2S(SERVICE.ACTIVITY, "wishPoolLottery", round, num)
	if ec ~= SystemError.success then
		return ec
	end

	resCtrl.costTreasure(roleId, cost, logConst.wishPoolCost)

	local goodsList = {}   --要发放的奖品
	for _,awardId in pairs(awards) do
		local conf = wishWellConfig[awardId]

		local awardInfo = conf.award or {}
		local sendStatus = WishPoolConst.sendStatus.inHandle
		if awardInfo.gunId or awardInfo.goodsId then
			table.insert(goodsList,awardInfo)
			sendStatus = WishPoolConst.sendStatus.done
		end

		local record = {
			goodsType = conf.type,
			showFlag = (conf.display == 1),
			goodsName = conf.content,
			nickname = roleInfo.nickname,
			prizeId = awardInfo.prizeId,
			status = sendStatus,
			round  = round,
		}

		dbHelp.send("wishPool.addRecord", roleId, record)
		if conf.notice == 1 then
			context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 12, words = {roleInfo.nickname, conf.content}})
		end
	end

	resCtrl.sendList(roleId, goodsList, logConst.wishPoolGet)
	-- print("awards",tableToString(awards))
	return SystemError.success , awards
end

--获取我的奖品
function WishPoolCtrl.getGoodsRecords(roleId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.wishPool)
	if not flag then
		return ActivityError.notOpen
	end
	local records = dbHelp.call("wishPool.getRecord", roleId, round, WishPoolConst.goodsType.real, 10)
	local result = {}
	for _, record in pairs(records) do
		result[#result+1] = {
			goodsName = record.goodsName,
			time = record.time,
			status = record.status,
		}
	end
	return SystemError.success, result
end

return WishPoolCtrl