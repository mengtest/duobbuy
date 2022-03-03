local dbHelp = require("common.db_help")
local resOperate = require("common.res_operate")
local configDb = require("config.config_db")
local logConst = require("game.log_const")
local rechargeActivityConf = configDb.recharge_activity
local activityConst = require("activity.activity_const")
local dailyActivityId = activityConst.dailyActivityId
local roundActivityId = activityConst.roundActivityId
local dailyActivityConf = configDb[rechargeActivityConf[dailyActivityId].params.config]
local roundActivityConf = configDb[rechargeActivityConf[roundActivityId].params.config]
local buttonStatus = activityConst.buttonStatus
local roleEvent = require("role.role_event")
local context = require("common.context")

local activityCtrl = {}

local function getCurDay()
	return os.date("%Y%m%d")
end

local function judgeRechargeInfoFunc(sec, activityId)
	sec = sec or os.time()
	local beginTime = rechargeActivityConf[activityId].beginTime
	if sec < beginTime then
		return false, 1
	end
	local lastTime, spaceTime = rechargeActivityConf[activityId].lastTime, rechargeActivityConf[activityId].spaceTime
	local passSec = sec - beginTime
	local round = math.ceil(passSec / (lastTime + spaceTime))
	local flagTime = passSec - (round - 1) * (lastTime + spaceTime)
	if flagTime <= lastTime then
		return true, round
	else
		return false, round
	end
end

function activityCtrl.getDailyRechargeInfo(roleId, day)
	local curDay = day or getCurDay()
	local rechargeInfo = dbHelp.call("activity.getDailyRechargeInfo", roleId, curDay)
	local price = rechargeInfo.price or 0
	local status = {}
	for index, conf in ipairs(dailyActivityConf) do
		if rechargeInfo[tostring(index)] then
			status[#status+1] = buttonStatus.over
		else
			if price >= conf.recharge then
				status[#status+1] = buttonStatus.award
			else
				status[#status+1] = buttonStatus.charge
			end
		end
	end
	local result = {
		price = price,
		status = status,
	}
	return result, curDay
end

function activityCtrl.getDailyRechargeAward(roleId, awardIndex)
	local rechargeInfo, curDay = activityCtrl.getDailyRechargeInfo(roleId)
	local status = rechargeInfo.status
	if status[awardIndex] and status[awardIndex] == buttonStatus.award then
		local award = dailyActivityConf[awardIndex].award
		dbHelp.call("activity.recordDailyAward", roleId, curDay, awardIndex)
		resOperate.send(roleId, award.goodsId, award.amount, logConst.dailyRechargeGet)
		return SystemError.success
	else
		return ActivityError.canNotGet
	end
end

function activityCtrl.getRoundRechargeInfo(roleId)
	local _, curRound = judgeRechargeInfoFunc(_, roundActivityId)
	local rechargeInfo = dbHelp.call("activity.getRoundRechargeInfo", roleId, curRound)
	local price = rechargeInfo.price or 0
	local status = {}
	for index, conf in ipairs(roundActivityConf) do
		if rechargeInfo[tostring(index)] then
			status[#status+1] = buttonStatus.over
		else
			if price >= conf.recharge then
				status[#status+1] = buttonStatus.award
			else
				status[#status+1] = buttonStatus.charge
			end
		end
	end
	local result = {
		price = price,
		status = status,
	}
	return result
end

function activityCtrl.getRoundRechargeAward(roleId, awardIndex)
	local _, curRound = judgeRechargeInfoFunc(_, roundActivityId)
	local rechargeInfo = activityCtrl.getRoundRechargeInfo(roleId)
	local status = rechargeInfo.status
	if status[awardIndex] and status[awardIndex] == buttonStatus.award then
		local award = roundActivityConf[awardIndex].award
		dbHelp.call("activity.recordRoundAward", roleId, curRound, awardIndex)
		resOperate.send(roleId, award.goodsId, award.amount, logConst.roundRechargeGet)
		return SystemError.success
	else
		return ActivityError.canNotGet
	end
end


-----------------------------------------------------------------------------

function activityCtrl.sendRedPoint(roleId)
	local rechargeInfo = activityCtrl.getDailyRechargeInfo(roleId)
	local status = rechargeInfo.status
	for _, v in pairs(status) do
		if v == buttonStatus.award then
			context.sendS2C(roleId, M_RedPoint.handleActive, {data = "Chongzhi"})
			break
		end
	end
	local roundRechargeInfo = activityCtrl.getRoundRechargeInfo(roleId)
	status = roundRechargeInfo.status
	for _, v in pairs(status) do
		if v == buttonStatus.award then
			context.sendS2C(roleId, M_RedPoint.handleActive, {data = "Chongzhi"})
			break
		end
	end
end

---------------------------------------------------------------------------------

function activityCtrl.onLogin(roleId)
	roleEvent.registerLoadOverEvent(function()
		activityCtrl.sendRedPoint(roleId)
	end)
end

-----------------------------------------------------------------------------------


return activityCtrl