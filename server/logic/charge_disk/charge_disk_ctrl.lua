local dbHelp   = require("common.db_help")
local context = require("common.context")
local resOperate = require("common.res_operate")
local logConst = require("game.log_const")
local configDb = require("config.config_db")
local roleCtrl = require("role.role_ctrl")
local skynet = require("skynet")
local roleEvent = require("role.role_event")

local chargeDiskCtrl = {}
local chargeDiskConst = require("charge_disk.charge_disk_const")
local activityTotalConfig = configDb.activity
local activityId = chargeDiskConst.activityId
local activityConf = activityTotalConfig[activityId]
local diskConfig = configDb[activityConf.params.config]
local diskGroupConfig = configDb.recharge_disk_group
local rechargeAmountConfig = configDb.recharge_amount_config

local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityStatus = require("activity.activity_const").activityStatus
local activityTimeConst = require("activity.activity_const").activityTime

-- function chargeDiskCtrl.getRollInfo(roleId)
-- 	local sTime, eTime = activityConf.startTime, activityConf.endTime
-- 	local chargeNum = context.callS2S(SERVICE.CHARGE, "getTotalPriceByTime", roleId, sTime, eTime)
-- 	local rollNum = math.floor(chargeNum / chargeDiskConst.moneyPre)
-- 	local joinNum = dbHelp.call("chargeDisk.getJoinNum", roleId)
-- 	local leftNum = rollNum - joinNum
-- 	if leftNum < 0 then leftNum = 0 end
-- 	return leftNum
-- end

-- function chargeDiskCtrl.rollDisk(roleId, rollNum)
-- 	local leftNum = chargeDiskCtrl.getRollInfo(roleId)
-- 	if leftNum < rollNum then
-- 		return ActivityError.diskNoNum
-- 	end
-- 	local luckyIndexs = {}
-- 	local awards = {}
-- 	local roleInfo = roleCtrl.getRoleInfo(roleId)
-- 	for i=1,rollNum do
-- 		local luckyInfo = chargeDiskCtrl.luckyRoll()
-- 		luckyIndexs[#luckyIndexs+1] = luckyInfo.id
-- 		awards[#awards+1] = luckyInfo.award
-- 		skynet.timeout(200, function()
-- 			context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 5, words = {roleInfo.nickname, luckyInfo.content}})
-- 		end)
-- 	end
-- 	resOperate.sendList(roleId, awards, logConst.chargeDiskGet)
-- 	dbHelp.call("chargeDisk.incrJoinNum", roleId, rollNum)	
-- 	return SystemError.success, luckyIndexs
-- end

-- function chargeDiskCtrl.luckyRoll()
-- 	local luckyNum = math.rand(1, 1000)
-- 	local luckyIndex
-- 	local starNum = 0
-- 	for i=1,#diskConfig do
-- 		local endNum = starNum + diskConfig[i].weight
-- 		if luckyNum > starNum and luckyNum <= endNum then
-- 			luckyIndex = diskConfig[i].id
-- 			break;
-- 		end
-- 		starNum = endNum
-- 	end
-- 	assert(luckyIndex, "luckyRoll func error")
-- 	return diskConfig[luckyIndex]
-- end

local function judgeDisckFunc(sec)
	local sec = sec or os.time()
	local activityInfo = activityTimeCtrl.getActivityTime(activityTimeConst.chargeDisk)
	if activityInfo then
		if activityInfo.status ~= activityStatus.open then
			return false
		end
		local flag = (sec >= activityInfo.sTime and sec <= activityInfo.eTime)
		return flag, activityInfo.round
	else
		
		local beginTime = activityConf.beginTime
		if sec < beginTime then
			return false
		end
		local lastTime, spaceTime = activityConf.lastTime, activityConf.spaceTime
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

local function getGroupConf(num)
	local curGroup, nextGroup = {}, {}
	for _,conf in ipairs(rechargeAmountConfig) do
		if num < conf.amount then
			nextGroup = conf
			break
		end
		curGroup = conf
	end
	return curGroup, nextGroup
end

function chargeDiskCtrl.getRollInfo(roleId)
	local flag, round = judgeDisckFunc()
	if not flag then
		return ActivityError.diskNotOpen
	end
	local diskInfo = dbHelp.call("chargeDisk.getDiskInfo", roleId, round)
	local chargeMoney = diskInfo.chargeMoney or 0
	local curGroup, nextGroup = getGroupConf(chargeMoney)
	local needCharge = 0
	if nextGroup.amount then
		needCharge = nextGroup.amount - chargeMoney
	end
	local getIds = {}
	for id in pairs(diskConfig) do
		if diskInfo[tostring(id)] then
			getIds[#getIds+1] = id
		end
	end
	local rollNum = 0
	if curGroup.amount then
		rollNum = curGroup.id - #getIds
	end
	local result = {}
	result.getIds = getIds
	result.needCharge = needCharge
	result.rollNum = rollNum
	-- print("chargeDiskCtrl.getRollInfo(roleId) roleId:"..roleId)
	-- dump(result)
	return SystemError.success, result
end

function chargeDiskCtrl.rollDisk(roleId)
	local flag, round = judgeDisckFunc()
	if not flag then
		return ActivityError.diskNotOpen
	end
	local diskInfo = dbHelp.call("chargeDisk.getDiskInfo", roleId, round)
	local chargeMoney = diskInfo.chargeMoney or 0
	local curGroup = getGroupConf(chargeMoney)
	local getIds = {}
	for id in pairs(diskConfig) do
		if diskInfo[tostring(id)] then
			getIds[#getIds+1] = id
		end
	end
	local rollNum = 0
	if curGroup.amount then
		rollNum = curGroup.id - #getIds
	end
	if rollNum <= 0 then
		return ActivityError.noRollNum
	end
	local curGroupId = curGroup.group or 1
	local canGetAwardIds = {}
	
	for i=curGroupId,1,-1 do
		local awardIds = diskGroupConfig[i].info
		for _,awardId in pairs(awardIds) do
			if not table.find(getIds, awardId) then
				canGetAwardIds[#canGetAwardIds+1] = awardId
			end
		end
	end
	if #canGetAwardIds <= 0 then
		return ActivityError.noRollNum
	end
	local luckyAwardId = canGetAwardIds[math.rand(1, #canGetAwardIds)]
	local awardInfo = diskConfig[luckyAwardId].award
	dbHelp.call("chargeDisk.setAwardIndex", roleId, round, luckyAwardId)
	if awardInfo.goodsId then	
		resOperate.send(roleId, awardInfo.goodsId, awardInfo.amount, logConst.chargeDiskGet)
	elseif awardInfo.gunId then
		resOperate.addGun(roleId, awardInfo.gunId, logConst.chargeDiskGet, awardInfo.time)
	end
	if diskConfig[luckyAwardId].notice == 1 then
		local roleInfo = roleCtrl.getRoleInfo(roleId)
		skynet.timeout(200, function()
			context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 10, words = {roleInfo.nickname, diskConfig[luckyAwardId].content}})
		end)
	end
	return SystemError.success, luckyAwardId
end

function chargeDiskCtrl.updateDiskInfo(roleId)
	local ec, diskInfo = chargeDiskCtrl.getRollInfo(roleId)
	if ec == SystemError.success then
		context.sendS2C(roleId, M_Activity.handleRollInfoUpdate, diskInfo)
	end
end

function chargeDiskCtrl.onLogin(roleId)
	roleEvent.registerChargeEvent(chargeDiskCtrl.updateDiskInfo)
end

return chargeDiskCtrl