local skynet = require("skynet")
local context = require("common.context")
local roleCtrl = require("role.role_ctrl")
local resOp = require("common.res_operate")
local dbHelp = require("common.db_help")

local roleEvent = require("role.role_event")

local treasureBowlConst = require("treasure_bowl.treasure_bowl_const")

local configDb = require("config.config_db")
local activityTotalConfig = configDb.activity
local activityConf = activityTotalConfig[treasureBowlConst.ACTIVITY_ID]
local treasureConfig = configDb[activityConf.params.config]

local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityStatus = require("activity.activity_const").activityStatus
local activityTimeConst = require("activity.activity_const").activityTime

local logConst = require("game.log_const")
local roleConst = require("role.role_const")

local treasureBowlCtrl = {}

function treasureBowlCtrl.getInfo(roleId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.treasureBowl)
	if not flag then
		return ActivityError.notOpen
	end
	local info = dbHelp.call("treasureBowl.getInfo", roleId, round)
	local chargeMoney = info.chargeMoney or 0
	local leftGold = info.leftGold or treasureBowlConst.INIT_GOLD
	local joinTimes = info.joinTimes or 0

	local leftTimes = 0
	local needCharge = 0
	local index = math.min(#treasureConfig, table.lowerBound(treasureConfig, chargeMoney, "amount"))
	local conf = treasureConfig[index]
	if conf.amount > chargeMoney then
		leftTimes = index - joinTimes - 1
		needCharge = conf.amount - chargeMoney
	else
		leftTimes = index - joinTimes
		local nextConf = treasureConfig[index + 1]
		needCharge = nextConf and (nextConf.amount - chargeMoney) or 0
	end

	local result = {}
	result.chargeMoney = chargeMoney
	result.leftGold = leftGold
	result.leftTimes = leftTimes
	result.needCharge = needCharge
	result.joinTimes = joinTimes
	
	return SystemError.success, result
end

function treasureBowlCtrl.join(roleId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.treasureBowl)
	if not flag then
		return ActivityError.notOpen
	end
	local info = dbHelp.call("treasureBowl.getInfo", roleId, round)
	local chargeMoney = info.chargeMoney or 0
	local leftGold = info.leftGold or treasureBowlConst.INIT_GOLD
	local joinTimes = info.joinTimes or 0

	local leftTimes = 0
	local index = math.min(#treasureConfig, table.lowerBound(treasureConfig, chargeMoney, "amount"))
	local conf = treasureConfig[index]
	if conf.amount > chargeMoney then
		leftTimes = index - joinTimes - 1
	else
		leftTimes = index - joinTimes
	end

	if leftTimes <= 0 then
		return TreasureBowlError.notLeftTimes
	end

	conf = treasureConfig[joinTimes + 1]

	local goldAmount
	if conf.max == 0 then
		goldAmount = leftGold
	else
		goldAmount = math.min(leftGold, math.rand(conf.min, conf.max))
	end

	resOp.send(roleId, roleConst.GOLD_ID, goldAmount, logConst.treasureBowlGet)
	leftGold = leftGold - goldAmount
	dbHelp.send("treasureBowl.updateInfo", roleId, round, joinTimes + 1, leftGold)

	if leftGold == 0 then
		local awardInfo = activityConf.params.award
		resOp.addGun(roleId, awardInfo.gunId, logConst.treasureBowlGet, awardInfo.time)
	end

	return SystemError.success, goldAmount
end

function treasureBowlCtrl.updateInfo(roleId)
	local ec, info = treasureBowlCtrl.getInfo(roleId)
	if ec == SystemError.success then
		context.sendS2C(roleId, M_TreasureBowl.onUpdateInfo, info)
	end
end

function treasureBowlCtrl.onLogin(roleId)
	-- roleEvent.registerChargeEvent(treasureBowlCtrl.updateInfo)
end

return treasureBowlCtrl