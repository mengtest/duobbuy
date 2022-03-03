local scoreLotteryCtrl = {}

local context = require('common.context')
local dbHelp = require("common.db_help")
local configDb = require("config.config_db")
local scoreLotteryConf = configDb.score_lottery_config
local scoreLotteryTotalConf = configDb.score_lottery_total

local scoreLotteryConst = require("score_lottery.score_lottery_const")
local awardStatus = scoreLotteryConst.awardStatus
local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityConst = require("activity.activity_const")
local activityTimeConst = activityConst.activityTime
local roleCtrl = require("role.role_ctrl")
local roleConst = require("role.role_const")
local logConst = require("game.log_const")
local activityStatus = require("activity.activity_const").activityStatus
local resCtrl = require("common.res_operate")


local function getRandInfo()
	-- 获取总概率
	local totalWeight = 0
	for _, info in pairs(scoreLotteryConf) do
		totalWeight = totalWeight + info.weight
	end
	-- 获取概率值	
	local randWeight = math.rand(1, totalWeight)

	local getInfo = {}
	local getWeight = 0
	for _, info in pairs(scoreLotteryConf) do
		if randWeight > getWeight and randWeight <= (getWeight + info.weight) then
			getInfo = info
			break
		end
		getWeight = getWeight + info.weight
	end
	return getInfo
end


function scoreLotteryCtrl.getInfo(roleId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.scoreLottery)
	if not flag then
		return ActivityError.notOpen
	end

	local info = dbHelp.call("scoreLottery.getInfo", roleId, round)
	local score = info.score or 0
	local lotteryTimes = info.lotteryTimes or 0
	local awardInfo = {}
	for k,v in pairs(scoreLotteryTotalConf) do
		local status = awardStatus.canNotGet
		if not info[tostring(k)] then
			if lotteryTimes >= v.times then
				status = awardStatus.canGet
			end
		else
			status = awardStatus.hasGet
		end
		table.insert(awardInfo, {id = k, status = status})
	end

	local result = {}
	result.leftScore = score - lotteryTimes * scoreLotteryConst.singleCost
	result.lotteryTimes = lotteryTimes
	result.awardInfos = awardInfo
	-- print("result",tableToString(result))
	return SystemError.success, result
end

function scoreLotteryCtrl.lottery(roleId, num)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.scoreLottery)
	if not flag then
		return ActivityError.notOpen
	end

	local info = dbHelp.call("scoreLottery.getInfo", roleId, round)
	local score = info.score or 0
	local lotteryTimes = info.lotteryTimes or 0
	local leftScore = score - lotteryTimes * scoreLotteryConst.singleCost
	if leftScore < scoreLotteryConst.singleCost * num then
		return ScoreLotteryError.scoreNotEnough
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId)

	local totalAward = {}
	local awardIds = {}
	for i=1, num do
		local randInfo = getRandInfo()
		-- table.insert(totalAward, randInfo.award)
		awardIds[#awardIds+1] = randInfo.id
		local awardInfo = randInfo.award or {}
		local sendStatus = scoreLotteryConst.sendStatus.inHandle
		if awardInfo.gunId or awardInfo.goodsId then
			table.insert(totalAward, awardInfo)
			sendStatus = scoreLotteryConst.sendStatus.done
		end

		local record = {
			goodsType = randInfo.type,
			goodsName = randInfo.content,
			nickname = roleInfo.nickname,
			prizeId = awardInfo.prizeId,
			status = sendStatus,
			round  = round,
		}

		dbHelp.send("scoreLottery.addRecord", roleId, record)
		if randInfo.notice == 1 then
			context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 17, words = {roleInfo.nickname, randInfo.content}})
		end
	end

	dbHelp.call("scoreLottery.incrLotteryTimes", roleId, round, num)

	resCtrl.sendList(roleId, totalAward, logConst.scoreLotteryGet)

	return SystemError.success, {awardIds = awardIds}

end

function scoreLotteryCtrl.getAward(roleId, awardId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.scoreLottery)
	if not flag then
		return ActivityError.notOpen
	end

	local info = dbHelp.call("scoreLottery.getInfo", roleId, round)
	local lotteryTimes = info.lotteryTimes or 0

	if info[tostring(awardId)] then
		return ActivityError.canNotGet
	end

	local conf = scoreLotteryTotalConf[awardId]
	if not conf then
		return SystemError.argument
	end
	
	if lotteryTimes < conf.times then
		return ActivityError.canNotGet 
	end

	dbHelp.call("scoreLottery.updateScoreLotteryInfo", roleId, round, awardId)

	local award = conf.award
	resCtrl.sendList(roleId, {award}, logConst.scoreLotteryGet)

	return SystemError.success
end

return scoreLotteryCtrl