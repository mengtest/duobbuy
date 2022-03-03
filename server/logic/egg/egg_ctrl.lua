local eggCtrl = {}

local context = require('common.context')
local dbHelp = require("common.db_help")
local configDb = require("config.config_db")
local eggCycleConfig = configDb.egg_cycle
local eggCycleConf = eggCycleConfig.eggCycle
local eggRechargeCycleConf = eggCycleConfig.eggRechargeCycle

local eggConst = require("crazy_box.crazy_box_const")
local initCycle = eggConst.initCycle
local maxCycle = eggConst.maxCycle
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


function eggCtrl.getInfo(roleId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.egg)
	if not flag then
		return ActivityError.notOpen
	end

	local record = dbHelp.call("egg.getInfo", roleId, round)
	record.eggInfos = record.eggInfos or {}
	record.chargeNum = record.chargeNum or 0
	record.cycle = record.cycle or initCycle
	record.openTimes = record.openTimes or 0
	record.positionIds = record.positionIds or {}

	local result = {}  --返回给前端的数据

	local curCycleEggInfo = {} --当前轮次已开启的宝箱id
	local canOpenTimes = 0 --当前轮次可开启次数
	for k,v in pairs(eggRechargeCycleConf[record.cycle]) do
		if record.chargeNum >= v.amount then
			canOpenTimes = canOpenTimes + 1
		end
		if table.find(record.eggInfos, v.id) then
			table.insert(curCycleEggInfo, v.id)
		end
	end

	result.eggInfos = curCycleEggInfo
	result.leftTimes = canOpenTimes - record.openTimes
	result.chargeNum = record.chargeNum
	result.cycle = record.cycle
	result.positionIds = record.positionIds
	-- print("result",tableToString(result))

	return SystemError.success, result  
end


function eggCtrl.openEgg(roleId, positionId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.egg)
	if not flag then
		return ActivityError.notOpen
	end

	if not positionId then
		return SystemError.argument
	end

	local record = dbHelp.call("egg.getInfo", roleId, round)
	record.eggInfos = record.eggInfos or {}
	record.chargeNum = record.chargeNum or 0
	record.cycle = record.cycle or initCycle
	record.openTimes = record.openTimes or 0
	record.positionIds = record.positionIds or {}
	if table.find(record.positionIds, positionId) then
		return EggError.isOpen
	end 

	local canOpenTimes = 0 --可开启次数
	local maxGroup = 1    --最高优先级
	for _,v in pairs(eggRechargeCycleConf[record.cycle]) do
		if record.chargeNum >= v.amount then
			canOpenTimes = canOpenTimes + 1
			if v.group > maxGroup then
				maxGroup = v.group
			end
		end
	end
	local leftTimes = canOpenTimes - record.openTimes --剩余次数
	if leftTimes <= 0 then
		return EggError.notLeftTimes
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId)

	local notOpenInfos = {}    --未开启的
	for _,v in pairs(eggCycleConf[record.cycle]) do
		if not table.find(record.eggInfos, v.id) and v.group <= maxGroup then
			table.insert(notOpenInfos, v)
		end
	end

	local randInfo = getRandInfo(notOpenInfos)
	--更新数据
	record.openTimes = record.openTimes + 1
	table.insert(record.eggInfos, randInfo.id)
	table.insert(record.positionIds, positionId)
	if record.openTimes >= 9 and record.cycle < maxCycle then
		local nextCycle = record.cycle + 1
		local data = {
			eggInfos = record.eggInfos,
			cycle = nextCycle,
			openTimes = 0,
			positionIds = {}, 
		}
		dbHelp.call("egg.updateEggInfo", roleId, round, data)
	else
		dbHelp.call("egg.updateEggInfo", roleId, round, {eggInfos = record.eggInfos, openTimes = record.openTimes, positionIds = record.positionIds})	
	end 

	local data = {
		goodsType = randInfo.type,
		goodsName = randInfo.content,
		nickname = roleInfo.nickname,
		round = round,
	}
	dbHelp.send("egg.addRecord", roleId, data)

	local awardInfo = randInfo.award or {}

	if randInfo.notice == 1 then
		context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 21, words = {roleInfo.nickname, randInfo.content}})
	end

	local ec = resCtrl.sendList(roleId, {awardInfo}, logConst.eggGet)
	if ec ~= SystemError.success then return ec end

	return SystemError.success, randInfo.id	
end

return eggCtrl