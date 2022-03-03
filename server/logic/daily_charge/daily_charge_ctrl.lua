local dailyChargeCtrl = {}

local context = require('common.context')
local dbHelp = require("common.db_help")
local configDb = require("config.config_db")
local continueRechargeConf = configDb.continue_recharge
local everydayRechargeConf = configDb.everyday_recharge

local dailyChargeConst = require("daily_charge.daily_charge_const")
local awardStatus = dailyChargeConst.awardStatus

local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityConst = require("activity.activity_const")
local activityTimeConst = activityConst.activityTime
local roleCtrl = require("role.role_ctrl")
local roleConst = require("role.role_const")
local logConst = require("game.log_const")
local activityStatus = require("activity.activity_const").activityStatus
local resCtrl = require("common.res_operate")

local function getCurDay()
	return os.date("%Y%m%d")
end

local function getCurMonth()
	return os.date("%Y%m")
end

local function getWeekDay()
	return os.date("*t").wday
end

function dailyChargeCtrl.getInfo(roleId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.dailyCharge)
	if not flag then
		return ActivityError.notOpen
	end

	local curDay = getCurDay()
	local month = getCurMonth()
	local info = dbHelp.call("dailyCharge.getInfo", roleId, month)

	local dayGetList = info.dayGetList or {}
	local chargeDays = info.chargeDays or 0
	local dayAwardStatus = awardStatus.canNotGet
	if info.lastChargeDate and info.lastChargeDate == curDay then
		if table.find(dayGetList, info.lastChargeDate) then
			dayAwardStatus = awardStatus.hasGet
		else
			dayAwardStatus = awardStatus.canGet
		end
	end

	local continueInfo = {}
	for k,v in pairs(continueRechargeConf) do
		local status = awardStatus.canNotGet
		if not info[tostring(k)] then
			if chargeDays >= v.day then
				status = awardStatus.canGet
			end
		else
			status = awardStatus.hasGet
		end
		table.insert(continueInfo, {days = v.day, status = status})
	end 

	local result = {}
	result.chargeDays = chargeDays
	result.dayAwardStatus = dayAwardStatus
	result.continueInfos = continueInfo
	-- print("result",tableToString(result))
	return SystemError.success, result
end

function dailyChargeCtrl.getDailyAward(roleId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.dailyCharge)
	if not flag then
		return ActivityError.notOpen
	end

	local curDay = getCurDay()
	local month = getCurMonth()
	local info = dbHelp.call("dailyCharge.getInfo", roleId, month)
	local dayGetList = info.dayGetList or {}

	if not info.lastChargeDate then
		return ActivityError.canNotGet
	end
	if curDay ~= info.lastChargeDate or table.find(dayGetList, curDay) then
		return ActivityError.canNotGet
	end
	table.insert(dayGetList, curDay)
	dbHelp.call("dailyCharge.updateDailyChargeInfo", roleId, month, "dayGetList", dayGetList)

	local weekday = getWeekDay()
	local conf = everydayRechargeConf[weekday]
	local award = conf.award
	resCtrl.sendList(roleId, award, logConst.dayChargeGet)

	return SystemError.success
end

function dailyChargeCtrl.getContinueAward(roleId, awardId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.dailyCharge)
	if not flag then
		return ActivityError.notOpen
	end

	local curDay = getCurDay()
	local month = getCurMonth()
	local info = dbHelp.call("dailyCharge.getInfo", roleId, month)
	local chargeDays = info.chargeDays or 0

	if info[tostring(awardId)] then
		return ActivityError.canNotGet
	end
	local conf = continueRechargeConf[awardId]

	if chargeDays < conf.day then
		return DailyChargeError.chargeDaysNotEnough
	end

	dbHelp.call("dailyCharge.updateDailyChargeInfo", roleId, month, tostring(awardId), true)

	dbHelp.call("dailyCharge.addRecord", roleId, conf.day)

	local award = conf.award
	resCtrl.sendList(roleId, {award}, logConst.dayChargeGet)

	return SystemError.success
end

return dailyChargeCtrl