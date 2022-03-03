local activityConst = require("activity.activity_const")
local activityStatus = activityConst.activityStatus
local configDb = require("config.config_db")
local activityTimeConfig = configDb.activity_time
local activityTimeCtrl = {}

function activityTimeCtrl.getActivityTime(activityId)
	if activityId then
		return activityTimeConfig[activityId]
	else
		return activityTimeConfig
	end
end

function activityTimeCtrl.isActivityOpen(activityId)
	if not activityId then
		return
	end
	local activityInfo = activityTimeCtrl.getActivityTime(activityId)
	if not activityInfo then
		return
	end
	if activityInfo.status ~= activityStatus.open then
		return false
	end
	local curSec = os.time()
	local flag = (curSec >= activityInfo.sTime and curSec <= activityInfo.eTime)
	return flag
end

function activityTimeCtrl.getRound(type, conf, sec)
	local sec = sec or os.time()
	local activityInfo = activityTimeCtrl.getActivityTime(type)
	if activityInfo then
		if activityInfo.status ~= activityStatus.open then
			return false
		end
		local flag = (sec >= activityInfo.sTime and sec <= activityInfo.eTime)
		return flag, activityInfo.round
	else
		if not conf then
			return false
		end
		local beginTime = conf.beginTime
		if sec < beginTime then
			return false
		end
		local lastTime, spaceTime = conf.lastTime, conf.spaceTime
		local passSec = sec - beginTime
		local round = math.ceil(passSec / (lastTime + spaceTime))
		local flagTime = passSec - (round - 1) * (lastTime + spaceTime)
		if flagTime <= lastTime then
			return true, round
		else
			return false
		end
	end
end

return activityTimeCtrl