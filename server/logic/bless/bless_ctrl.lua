local blessCtrl = {}

local context = require('common.context')
local dbHelp = require("common.db_help")
local configDb = require("config.config_db")
local blessConfig = configDb.bless_config
local blessConst = require("bless.bless_const")
local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityConst = require("activity.activity_const")
local activityTimeConst = activityConst.activityTime
local roleCtrl = require("role.role_ctrl")
local roleConst = require("role.role_const")
local logConst = require("game.log_const")
local activityStatus = require("activity.activity_const").activityStatus
local resCtrl = require("common.res_operate")


function blessCtrl.getInfo(roleId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.bless)
	if not flag then
		return ActivityError.notOpen
	end
	local blessInfo = dbHelp.call("bless.getInfo", roleId)
	if table.empty(blessInfo) then
		for k,v in pairs(blessConfig) do
			blessInfo[tostring(k)] = 0
		end
		dbHelp.send("bless.initBlessInfo", roleId, blessInfo)
	end

	local result = {infos = {}}
	for k,v in pairs(blessInfo) do
		table.insert(result.infos, {id = tonumber(k), luckValue = v})
	end
	-- print("result",tableToString(result))
	return SystemError.success, result
end

function blessCtrl.bless(roleId, blessId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.bless)
	if not flag then
		return ActivityError.notOpen
	end

	local conf = blessConfig[blessId]
	if not conf then
		return SystemError.argument
	end

	local ec = resCtrl.costTreasure(roleId, blessConst.blessTreasureCost, logConst.blessCost)
	if ec ~= SystemError.success then
		return ec
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId)
	local blessValue = dbHelp.call("bless.getBlessValue", roleId, blessId)
	if not blessValue then
		return SystemError.argument
	end

	local goodsList = {}   --要发放的奖品
	table.insert(goodsList, blessConst.blessMustGet) --祈福必得奖励

	local rate = conf.rate + math.floor(blessValue * conf.addition / 10000)
	if math.rand(1,1000000) <= rate then
		local awardInfo = conf.award
		local sendStatus = blessConst.sendStatus.inHandle
		if conf.type ~= blessConst.goodsType.real then
			table.insert(goodsList, awardInfo)
			sendStatus = blessConst.sendStatus.done
		end

		local record = {
			goodsType = conf.type,
			goodsName = conf.content,
			nickname = roleInfo.nickname,
			prizeId = awardInfo.prizeId,
			status = sendStatus,
		}

		dbHelp.call("bless.addRecord", roleId, record)
		if conf.notice == 1 then
			context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 16, words = {roleInfo.nickname, conf.content}})
		end
		blessValue = 0
	else
		blessValue = blessValue + conf.luck
	end
	--祈福次数记录(后台统计需要)
	dbHelp.call("bless.addBlessTimesRecord", roleId, conf.content)

	dbHelp.call("bless.updateBless", roleId, blessId, blessValue)

	resCtrl.sendList(roleId, goodsList, logConst.blessGet)

	return SystemError.success, blessValue
end


--幸运值满，直接领取
function blessCtrl.getAward(roleId, blessId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.bless)
	if not flag then
		return ActivityError.notOpen
	end

	local conf = blessConfig[blessId]
	if not conf then
		return SystemError.argument
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId)
	local blessValue = dbHelp.call("bless.getBlessValue", roleId, blessId)
	if not blessValue or blessValue < 1000000 then
		return BlessError.luckyValueNotFull
	end
	local awardInfo = conf.award
	local sendStatus = blessConst.sendStatus.inHandle
	if conf.type ~= blessConst.goodsType.real then
		sendStatus = blessConst.sendStatus.done
	end

	local record = {
		goodsType = conf.type,
		goodsName = conf.content,
		nickname = roleInfo.nickname,
		prizeId = awardInfo.prizeId,
		status = sendStatus,
		round  = round,
	}
	dbHelp.call("bless.addRecord", roleId, record)
	if conf.notice == 1 then
		context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 16, words = {roleInfo.nickname, conf.content}})
	end

	--幸运值清0
	dbHelp.call("bless.updateBless", roleId, blessId, 0)

	if conf.type ~= blessConst.goodsType.real then
		resCtrl.sendList(roleId, {awardInfo}, logConst.blessGet)
	end

	return SystemError.success
end

--获取我的奖品
function blessCtrl.getGoodsRecords(roleId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.bless)
	if not flag then
		return ActivityError.notOpen
	end
	local records = dbHelp.call("bless.getRecord", roleId, blessConst.goodsType.real, 10)
	local result = {}
	for _, record in pairs(records) do
		result[#result+1] = {
			goodsName = record.goodsName,
			time = record.time,
			status = record.status,
		}
	end
	-- print("result",tableToString(result))
	return SystemError.success, result
end

return blessCtrl