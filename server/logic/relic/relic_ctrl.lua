local relicCtrl = {}

local context = require('common.context')
local dbHelp = require("common.db_help")
local configDb = require("config.config_db")
local relicConf = configDb.relic_config

local relicConst = require("relic.relic_const")

local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityConst = require("activity.activity_const")
local activityTimeConst = activityConst.activityTime
local roleCtrl = require("role.role_ctrl")
local roleConst = require("role.role_const")
local logConst = require("game.log_const")
local activityStatus = require("activity.activity_const").activityStatus
local resCtrl = require("common.res_operate")

local function getRandInfo(randList)
	-- 获取总概率
	local totalWeight = 0
	for _, info in pairs(randList) do
		totalWeight = totalWeight + info.weight
	end
	-- 获取概率值
	local randWeight = 0
	if totalWeight > 0 then
		randWeight = math.rand(1, totalWeight)
	end
	local getInfo = {}
	local getWeight = 0
	for _, info in pairs(randList) do
		if randWeight > getWeight and randWeight <= (getWeight + info.weight) then
			getInfo = info
			break
		end
		getWeight = getWeight + info.weight
	end
	return getInfo
end

function relicCtrl.getInfo(roleId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.relic)
	if not flag then
		return ActivityError.notOpen
	end

	local info = dbHelp.call("relic.getInfo", roleId)
	local level = info.level or 1

	return SystemError.success, level
end

function relicCtrl.lottery(roleId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.relic)
	if not flag then
		return ActivityError.notOpen
	end

	local ec = resCtrl.costTreasure(roleId, relicConst.singleCost, logConst.relicCost)
	if ec ~= SystemError.success then
		return ec
	end

	local info = dbHelp.call("relic.getInfo", roleId)
	local level = info.level or 1
	local randList = relicConf[level]
	if not randList then
		return SystemError.argument
	end

	local randInfo = getRandInfo(randList)

	local roleInfo = roleCtrl.getRoleInfo(roleId)
	local goodsList = {}
	local awardInfo = randInfo.award or {}
	local sendStatus = relicConst.sendStatus.inHandle
	if awardInfo.gunId or awardInfo.goodsId then
		table.insert(goodsList,awardInfo)
		sendStatus = relicConst.sendStatus.done
	end

	local record = {
		goodsType = randInfo.type,
		goodsName = randInfo.content,
		nickname = roleInfo.nickname,
		prizeId = awardInfo.prizeId,
		status = sendStatus,
	}

	dbHelp.send("relic.addRecord", roleId, record)
	if randInfo.notice == 1 then
		context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 20, words = {roleInfo.nickname, randInfo.content}})
	end

	resCtrl.sendList(roleId, goodsList, logConst.relicGet)
	if randInfo.sign ~= 0 then
		if randInfo.sign == relicConst.sign.up then
			level = level + 1
		elseif randInfo.sign == relicConst.sign.down then
			level = level - 1
		elseif randInfo.sign == relicConst.sign.reset then
			level = 1	
		end
		dbHelp.call("relic.updateRelicInfo", roleId, level)
	end

	local result = {}
	result.id = randInfo.id
	result.level = level
	-- print("result",tableToString(result))

	return SystemError.success, result
end

--获取我的奖品
function relicCtrl.getGoodsRecords(roleId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.relic)
	if not flag then
		return ActivityError.notOpen
	end
	local records = dbHelp.call("relic.getRecord", roleId, relicConst.goodsType.real, 10)
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


return relicCtrl