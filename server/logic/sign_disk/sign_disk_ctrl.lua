local signDiskCtrl = {}
local signDiskConst = require("sign_disk.sign_disk_const")
local dbHelp = require("common.db_help")
local context = require("common.context")
local resCtrl = require("common.res_operate")
local logConst = require("game.log_const")
local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityTimeConst = require("activity.activity_const").activityTime
local totalSignConfig = require("config.total_sign")
local signDiskRate = require("config.config_db").sign_disk_rate
local totalWeight = signDiskRate.totalWeight
local rateData	= signDiskRate.data

--随机抽奖
local function randDraw()
	local randNum = math.rand(1, totalWeight)
	local drawInfo 
	for i, v in ipairs(rateData) do
		if randNum <= v.weight then
			drawInfo = v
			break
		end
	end
	return drawInfo
end


--获取月累计奖励状态信息
function signDiskCtrl.getTotalSignStatusInfo(roleId, yMonth)
	local info = dbHelp.call("signDisk.getTotalSignInfo", roleId, yMonth)
	if info  == nil then
		info  =	signDiskCtrl.initTotalSignInfo(roleId, yMonth)
	end
	return info
end

--初始化累计签到奖励状态
function signDiskCtrl.initTotalSignInfo(roleId, yMonth)
	local initStatus = signDiskConst.totalAwardStatus.notGet
	local info = {}
	for index, conf in ipairs(totalSignConfig) do
		info[index] = initStatus
	end
	dbHelp.call("signDisk.setTotalSignInfo", roleId, yMonth, info)
	return info
end

--更新月累计状态奖励信息
function signDiskCtrl.updateTotalSignInfo(roleId, yMonth)
	local result = signDiskCtrl.getInfo(roleId)
	local signDaysNum = result.signDaysNum
	local info = result.totalInfos
	for index, conf in ipairs(totalSignConfig) do
		if info[index] == signDiskConst.totalAwardStatus.notGet then
			if signDaysNum >= conf.day then
				info[index] = signDiskConst.totalAwardStatus.canGet
			end
		end
	end
	dbHelp.send("signDisk.updateTotalSignInfo", roleId, yMonth, info)
end

--获取界面信息
function signDiskCtrl.getInfo(roleId)
	local day  = os.date("%Y%m%d")
	local yMonth = os.date("%Y%m")
	local result = {signDaysNum = 0, totalInfos = {}, isSigned = false}
	result.signDaysNum = dbHelp.call("signDisk.getTotalSignDays", roleId, yMonth)
	result.totalInfos = signDiskCtrl.getTotalSignStatusInfo(roleId, yMonth)
	result.isSigned = dbHelp.call("signDisk.judgeHadSignDrawByDay", roleId, day)
	return result
end

--签到抽奖
function signDiskCtrl.signDraw(roleId)
	if not activityTimeCtrl.isActivityOpen(activityTimeConst.signDisk) then
		return ActivityError.notOpen
	end
	local day  = os.date("%Y%m%d")
	local yMonth = os.date("%Y%m")
	local hadDrawToday = dbHelp.call("signDisk.judgeHadSignDrawByDay", roleId, day)
	if hadDrawToday then
		return SignDiskError.hadDrawToday
	end
	local randDrawInfo = randDraw()
	local award = randDrawInfo.award
	if award.goodsId then
		resCtrl.send(roleId, award.goodsId, award.amount, logConst.signDiskGet)
	elseif award.gunId then
		resCtrl.addGun(roleId, award.gunId, logConst.signDiskGet, award.time)
	end
	dbHelp.call("signDisk.addDrawRecord", roleId, yMonth, day)
	signDiskCtrl.updateTotalSignInfo(roleId, yMonth)
	return SystemError.success,randDrawInfo.id
end

--领取累计奖励
function signDiskCtrl.getTotalSignAward(roleId, index)
	if not activityTimeCtrl.isActivityOpen(activityTimeConst.signDisk) then
		return ActivityError.notOpen
	end
	local yMonth = os.date("%Y%m")
	local info = signDiskCtrl.getTotalSignStatusInfo(roleId, yMonth)
	if info[index] == signDiskConst.totalAwardStatus.notGet then
		return SignDiskError.awardCanNotGet
	elseif info[index] == signDiskConst.totalAwardStatus.hadGet then
		return SignDiskError.awardHadGet
	elseif info[index] == signDiskConst.totalAwardStatus.canGet then
		local award = totalSignConfig[index].award
		if award.goodsId then
			resCtrl.send(roleId, award.goodsId, award.amount, logConst.signDiskGet)
		elseif award.gunId then
			resCtrl.addGun(roleId, award.gunId, logConst.signDiskGet, award.time)
		end
		info[index] = signDiskConst.totalAwardStatus.hadGet
		dbHelp.send("signDisk.updateTotalSignInfo", roleId, yMonth, info)
	end
	return SystemError.success
end

return signDiskCtrl