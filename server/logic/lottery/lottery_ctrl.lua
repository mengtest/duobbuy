local lotteryConst = require("lottery.lottery_const")
local roleCtrl = require("role.role_ctrl")
local roleConst = require("role.role_const")
local resCtrl = require("common.res_operate")
local logConst = require("game.log_const")
local dbHelp = require("common.db_help")
local context = require("common.context")

local lotteryConst = require("lottery.lottery_const")

local configDb = require("config.config_db")
local lotteryConfig = configDb.lottery_rate

local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityTimeConst = require("activity.activity_const").activityTime

local lotteryCtrl = {}

local GOLD_PER_ONE_SCORE = 1000

-- 随机数值
local function rand()
	local rate = math.rand(1, lotteryConfig.total)
	local info
	for _, v in ipairs(lotteryConfig.data) do
		if rate <= v.weight then
			info = v
			break
		end
	end
	return info
end

function lotteryCtrl.lottery(roleId, num)
	if num ~= 1 and num ~= 10 then
		return SystemError.argument
	end

	local flag, round = activityTimeCtrl.getRound(activityTimeConst.lottery)
	if not flag then
		return ActivityError.notOpen
	end

	local ec = resCtrl.costTreasure(roleId, num * lotteryConst.treasureRate, logConst.lotteryCost)
	if ec ~= SystemError.success then
		return ec
	end

	local awards = {}
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	for i = 1, num do
		local info = rand()
		local awardInfo = info.award or {}

		local sendStatus = lotteryConst.sendStatus.inHandle
		if awardInfo.gunId then
			resCtrl.addGun(roleId, awardInfo.gunId, logConst.lotteryGet, awardInfo.time)
			sendStatus = lotteryConst.sendStatus.done
		elseif awardInfo.goodsId then
			resCtrl.send(roleId, awardInfo.goodsId, awardInfo.amount, logConst.lotteryGet)
			sendStatus = lotteryConst.sendStatus.done
		end
		awards[#awards+1] = info.id

		local record = {
			goodsType = info.type,
			goodsName = info.content,
			showFlag = info.notice == 1,
			nickname = roleInfo.nickname,
			prizeId = awardInfo.prizeId,
			status = sendStatus,
		}

		dbHelp.send("lottery.addRecord", roleId, round, record)
		if info.notice == 1 then
			context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 14, words = {roleInfo.nickname, info.content}})
			context.castS2C(nil, M_Lottery.handleSysLottery, {goodsName = record.goodsName, nickname = record.nickname})
		end
	end
	
	local addScore = num * GOLD_PER_ONE_SCORE
	local ret = dbHelp.call("lottery.updateScore", roleId, round, num, addScore)
	local totalAward = context.callS2S(SERVICE.ACTIVITY, "updateLotteryScore",
		 roleId, roleInfo.nickname, ret.joinTimes, ret.score, addScore)
	return SystemError.success, {data = awards, totalAward = totalAward}
end

function lotteryCtrl.getSysRecord(round)
	local records = dbHelp.call("lottery.getRecord", nil, round, nil, true, 10)
	local result = {}
	for _,record in pairs(records) do
		result[#result+1] = {
			nickname = record.nickname,
			goodsName = record.goodsName,
		}
	end
	return result
end

function lotteryCtrl.getSelfRecord(roleId, round)
	local records = dbHelp.call("lottery.getRecord", roleId, round, nil, nil, 10)
	local result = {}
	for _, record in pairs(records) do
		result[#result + 1] = {
			nickname = record.nickname,
			goodsName = record.goodsName,
		}
	end
	return result
end

function lotteryCtrl.getGoodsRecord(roleId)
	local records = dbHelp.call("lottery.getRecord", roleId, round, lotteryConst.goodsType.real, nil, 10)
	local result = {}
	for _, record in pairs(records) do
		result[#result+1] = {
			goodsName = record.goodsName,
			time = record.time,
			status = record.status,
		}
	end
	return result
end

function lotteryCtrl.getInfo(roleId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.lottery)
	if not flag then
		return ActivityError.notOpen
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId, round)
	local sysRecords = lotteryCtrl.getSysRecord(round)
	local selfRecords = lotteryCtrl.getSelfRecord(roleId, round)
	local totalAward = context.callS2S(SERVICE.ACTIVITY, "getLotteryTotalScore")
	local result = {
		sysRecords = sysRecords,
		selfRecords = selfRecords,
		totalAward = totalAward,
	}
	return SystemError.success, result
end

function lotteryCtrl.getRankInfo(roleId)
	local info = context.callS2S(SERVICE.ACTIVITY, "getLotteryRank")
	return SystemError.success, {items = info}
end

return lotteryCtrl