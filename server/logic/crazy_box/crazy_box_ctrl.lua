local crazyBoxCtrl = {}

local context = require('common.context')
local dbHelp = require("common.db_help")
local configDb = require("config.config_db")
local crazyCycleConf = configDb.crazy_cycle
local crazyBoxCycleConf = crazyCycleConf.crazyBoxCycle
local crazyRechargeCycleConf = crazyCycleConf.crazyRechargeCycle

local crazyBoxConst = require("crazy_box.crazy_box_const")
local initCycle = crazyBoxConst.initCycle
local maxCycle = crazyBoxConst.maxCycle
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


function crazyBoxCtrl.getInfo(roleId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.crazyBox)
	if not flag then
		return ActivityError.notOpen
	end

	local record = dbHelp.call("crazyBox.getInfo", roleId, round)
	record.boxInfos = record.boxInfos or {}
	record.chargeNum = record.chargeNum or 0
	record.cycle = record.cycle or initCycle
	record.openTimes = record.openTimes or 0
	record.positionIds = record.positionIds or {}

	local result = {}  --返回给前端的数据

	local curCycleBoxInfo = {} --当前轮次已开启的宝箱id
	local canOpenTimes = 0 --当前轮次可开启次数
	for k,v in pairs(crazyRechargeCycleConf[record.cycle]) do
		if record.chargeNum >= v.amount then
			canOpenTimes = canOpenTimes + 1
		end
		if table.find(record.boxInfos, v.id) then
			table.insert(curCycleBoxInfo, v.id)
		end
	end

	result.boxInfos = curCycleBoxInfo
	result.leftTimes = canOpenTimes - record.openTimes
	result.chargeNum = record.chargeNum
	result.cycle = record.cycle
	result.positionIds = record.positionIds
	-- print("result",tableToString(result))

	return SystemError.success, result  
end


function crazyBoxCtrl.openBox(roleId, positionId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.crazyBox)
	if not flag then
		return ActivityError.notOpen
	end

	if not positionId then
		return SystemError.argument
	end

	local record = dbHelp.call("crazyBox.getInfo", roleId, round)
	record.boxInfos = record.boxInfos or {}
	record.chargeNum = record.chargeNum or 0
	record.cycle = record.cycle or initCycle
	record.openTimes = record.openTimes or 0
	record.positionIds = record.positionIds or {}
	if table.find(record.positionIds, positionId) then
		return CrazyBoxError.isOpen
	end 

	local canOpenTimes = 0 --可开启次数
	local maxGroup = 1    --最高优先级
	for _,v in pairs(crazyRechargeCycleConf[record.cycle]) do
		if record.chargeNum >= v.amount then
			canOpenTimes = canOpenTimes + 1
			if v.group > maxGroup then
				maxGroup = v.group
			end
		end
	end
	local leftTimes = canOpenTimes - record.openTimes --剩余次数
	if leftTimes <= 0 then
		return CrazyBoxError.notLeftTimes
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId)

	local notOpenInfos = {}    --未开启的
	for _,v in pairs(crazyBoxCycleConf[record.cycle]) do
		if not table.find(record.boxInfos, v.id) and v.group <= maxGroup then
			table.insert(notOpenInfos, v)
		end
	end

	local randInfo = getRandInfo(notOpenInfos)
	--更新数据
	record.openTimes = record.openTimes + 1
	table.insert(record.boxInfos, randInfo.id)
	table.insert(record.positionIds, positionId)
	if record.openTimes >= 12 and record.cycle < maxCycle then
		local nextCycle = record.cycle + 1
		local data = {
			boxInfos = record.boxInfos,
			cycle = nextCycle,
			openTimes = 0,
			positionIds = {}, 
		}
		dbHelp.call("crazyBox.updateCrazyBoxInfo", roleId, round, data)
	else
		dbHelp.call("crazyBox.updateCrazyBoxInfo", roleId, round, {boxInfos = record.boxInfos, openTimes = record.openTimes, positionIds = record.positionIds})	
	end 

	local awardInfo = randInfo.award or {}

	if randInfo.notice == 1 then
		context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 15, words = {roleInfo.nickname, randInfo.content}})
	end

	local ec = resCtrl.sendList(roleId, {awardInfo}, logConst.crazyBoxGet)
	if ec ~= SystemError.success then return ec end

	return SystemError.success, randInfo.id	
end

--获取我的奖品
function crazyBoxCtrl.getGoodsRecords(roleId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.crazyBox)
	if not flag then
		return ActivityError.notOpen
	end
	local records = dbHelp.call("crazyBox.getRecord", roleId, crazyBoxConst.goodsType.real, 10)
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

return crazyBoxCtrl