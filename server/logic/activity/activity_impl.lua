local chargeDiskCtrl = require("charge_disk.charge_disk_ctrl")
local shareCtrl = require("share.share_ctrl")
local activityCtrl = require("activity.activity_ctrl")
local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityStatus = require("activity.activity_const").activityStatus
local activityImpl = {}

function activityImpl.getRollInfo(roleId)
	return chargeDiskCtrl.getRollInfo(roleId)
end

function activityImpl.rollDisk(roleId, num)
	return chargeDiskCtrl.rollDisk(roleId, num)
end

function activityImpl.shareSuccess(roleId)
	return shareCtrl.shareSuccess(roleId)
end

function activityImpl.getDailyRechargeInfo(roleId)
	local result = activityCtrl.getDailyRechargeInfo(roleId)
	return SystemError.success, result
end

function activityImpl.getDailyRechargeAward(roleId, awardIndex)
	return activityCtrl.getDailyRechargeAward(roleId, awardIndex)
end

function activityImpl.getRoundRechargeInfo(roleId)
	local result = activityCtrl.getRoundRechargeInfo(roleId)
	return SystemError.success, result
end

function activityImpl.getRoundRechargeAward(roleId, awardIndex)
	return activityCtrl.getRoundRechargeAward(roleId, awardIndex)
end

function activityImpl.getActivityTime(roleId)
	local configs = activityTimeCtrl.getActivityTime()
	local result = {}
	for _,v in pairs(configs) do
		result[#result+1] = {
			activityId = v.activityId,
			status = (v.status == activityStatus.open),
			sTime = v.sTime,
			eTime = v.eTime,
		}
	end
	return SystemError.success, {list = result}
end

return activityImpl