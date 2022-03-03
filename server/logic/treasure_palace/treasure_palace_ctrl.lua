local treasurePalaceCtrl = {}

local context = require('common.context')
local dbHelp = require("common.db_help")
local configDb = require("config.config_db")
local treasurePalaceConf = configDb.treasure_palace_config
local treasurePalaceBox = configDb.treasure_palace_box

local treasurePalaceConst = require("treasure_palace.treasure_palace_const")
local Source = treasurePalaceConst.Source

local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityConst = require("activity.activity_const")
local activityTimeConst = activityConst.activityTime
local roleCtrl = require("role.role_ctrl")
local roleConst = require("role.role_const")
local logConst = require("game.log_const")
local activityStatus = require("activity.activity_const").activityStatus
local resCtrl = require("common.res_operate")

local function getRandAward(randList)
	local totalWeight = 0
	for _,v in pairs(randList) do
		totalWeight = totalWeight + v.weight
	end

	local randWeight = math.rand(1, totalWeight)

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


function treasurePalaceCtrl.getInfo(roleId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.treasurePalace)
	if not flag then
		return ActivityError.notOpen
	end

	local info = dbHelp.call("treasurePalace.getInfo", roleId)
	local position = info.position or 0 
	local openTimes = info.openTimes or 0

	local result = {}
	result.position = position
	result.openTimes = openTimes
	-- print("result",tableToString(result))
	return SystemError.success, result

end

function treasurePalaceCtrl.dice(roleId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.treasurePalace)
	if not flag then
		return ActivityError.notOpen
	end

	local ec = resCtrl.costTreasure(roleId, treasurePalaceConst.diceCost, logConst.treasurePalaceCost)
	if ec ~= SystemError.success then
		return ec
	end

	local info = dbHelp.call("treasurePalace.getInfo", roleId)
	local position = info.position or 0
	local beginPos =  position + 1
	local endPos = position + 6
	local posList = {}
	for i = beginPos, endPos do
		local pos = math.fmod(i, 18)
		if pos == 0 then
			posList[#posList+1] = 18
		else
			posList[#posList+1] = pos
		end
	end
	
	local randList = {}
	for k,v in pairs(treasurePalaceConf) do
		if table.find(posList, k) then
			randList[#randList+1] = v
		end 
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId)

	local randInfo = getRandAward(randList)
	local awardInfo = randInfo.award or {}
	if awardInfo.times then
		dbHelp.call("treasurePalace.incrOpenTimes", roleId, awardInfo.times)
	else
		local goodsList = {}
		local sendStatus = treasurePalaceConst.sendStatus.inHandle
		if awardInfo.gunId or awardInfo.goodsId then
			table.insert(goodsList,awardInfo)
			sendStatus = treasurePalaceConst.sendStatus.done
		end
		local record = {
			goodsType = randInfo.type,
			goodsName = randInfo.content,
			nickname = roleInfo.nickname,
			prizeId = awardInfo.prizeId,
			status = sendStatus,
			source = Source.map,
		}

		dbHelp.send("treasurePalace.addRecord", roleId, record)

		resCtrl.sendList(roleId, goodsList, logConst.treasurePalaceGet)
	end

	dbHelp.call("treasurePalace.updatePosition", roleId, randInfo.id)

	return SystemError.success, randInfo.id

end

function treasurePalaceCtrl.openBox(roleId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.treasurePalace)
	if not flag then
		return ActivityError.notOpen
	end

	local info = dbHelp.call("treasurePalace.getInfo", roleId)
	local openTimes = info.openTimes or 0
	if openTimes <= 0 then
		return TreasurePalaceError.openTimesNotEnough
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId)

	local randInfo = getRandAward(treasurePalaceBox)
	local goodsList = {}
	local awardInfo = randInfo.award or {}
	local sendStatus = treasurePalaceConst.sendStatus.inHandle
	if awardInfo.gunId or awardInfo.goodsId then
		table.insert(goodsList,awardInfo)
		sendStatus = treasurePalaceConst.sendStatus.done
	end
	local record = {
		goodsType = randInfo.type,
		goodsName = randInfo.content,
		nickname = roleInfo.nickname,
		prizeId = awardInfo.prizeId,
		status = sendStatus,
		source = Source.box,
	}

	dbHelp.send("treasurePalace.addRecord", roleId, record)

	if randInfo.notice == 1 then
		context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 19, words = {roleInfo.nickname, randInfo.content}})
	end

	dbHelp.call("treasurePalace.incrOpenTimes", roleId, -1)

	resCtrl.sendList(roleId, goodsList, logConst.treasurePalaceGet)

	return SystemError.success, randInfo.id
end

--获取我的奖品
function treasurePalaceCtrl.getGoodsRecords(roleId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.treasurePalace)
	if not flag then
		return ActivityError.notOpen
	end
	local records = dbHelp.call("treasurePalace.getRecord", roleId, treasurePalaceConst.goodsType.real, 10)
	local result = {}
	for _, record in pairs(records) do
		result[#result+1] = {
			goodsName = record.goodsName,
			time = record.time,
			status = record.status,
		}
	end

	return SystemError.success, {records = result}
end


return treasurePalaceCtrl