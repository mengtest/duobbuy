local luckyBagConst = require("lucky_bag.lucky_bag_const")
local roleCtrl = require("role.role_ctrl")
local roleConst = require("role.role_const")
local resCtrl = require("common.res_operate")
local logConst = require("game.log_const")
local dbHelp = require("common.db_help")
local configDb = require("config.config_db")
local context = require("common.context")
local bagRateConf = configDb.lucky_bag_rate
local bagRateData = bagRateConf.data
local bagRateTotal = bagRateConf.total
local LuckyBagConfig = require("config.lucky_bag_config")

local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityTimeConst = require("activity.activity_const").activityTime

local luckyBagCtrl = {}

-- 随机数值
local function bagRand()
	local luckyNum = math.rand(1, bagRateTotal)
	local luckyInfo
	for _,v in ipairs(bagRateData) do
		if luckyNum <= v.weight then
			luckyInfo = v
			break
		end
	end
	return luckyInfo
end

-- 获得桌子
function getRandomDesk(bag_type, lucky_bag_num)
	-- print("getRandomDesk(bag_type:"..bag_type..", lucky_bag_num:"..lucky_bag_num..")")
	local totalWeight = 0
	local randomDesk = {}
	for _,LuckyBagVO in pairs(LuckyBagConfig) do
		if LuckyBagVO.bag_type == bag_type then
			if LuckyBagVO.num[1] <= lucky_bag_num and (lucky_bag_num <= LuckyBagVO.num[2] or LuckyBagVO.num[2] == -1) then
				if LuckyBagVO.weight > 0 then
					totalWeight = totalWeight + LuckyBagVO.weight
					table.insert(randomDesk, LuckyBagVO)
				end
			end
		end
	end
	return totalWeight, randomDesk
end

function luckyBagCtrl.costRes(roleId, num)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if roleInfo.bag + math.floor(roleInfo.treasure / luckyBagConst.treasureRate) < num then
		return GameError.treasureNotEnough
	end
	local costList = {}
	if roleInfo.bag >= num then
		costList[#costList+1] = {goodsId = roleConst.LUCKY_BAG_ID, amount = num}
	else
		local treasureCost = (num - roleInfo.bag) * luckyBagConst.treasureRate
		costList= {{goodsId = roleConst.LUCKY_BAG_ID, amount = roleInfo.bag}, {goodsId = roleConst.TREASURE_ID, amount = treasureCost}}
	end
	local ec = resCtrl.costList(roleId, costList, logConst.luckyBagCost)
	return ec
end

function luckyBagCtrl.open(roleId, num)
	local type = 1
	if not num then
		num = 1
	end
	if num ~= 1 then
		num = 10
		type = 2
	end
	if not activityTimeCtrl.isActivityOpen(activityTimeConst.luckyBag) then
		return ActivityError.notOpen
	end

	local ec = luckyBagCtrl.costRes(roleId, num)
	if ec ~= SystemError.success then
		return ec
	end
	
	-- 构造桌子
	local lucky_bag_type_num = "lucky_bag_"..type.."_num"
	local lucky_bag_num = dbHelp.call("luckyBag.getAttrVal", roleId, lucky_bag_type_num) or 0
	-- lucky_bag_num = 0
	dbHelp.call("luckyBag.incrAttrVal", roleId, lucky_bag_type_num, 1)
	lucky_bag_num = lucky_bag_num + 1
	-- print("lucky_bag_num:"..lucky_bag_num)
	local totalWeight, randomDesk = getRandomDesk(type, lucky_bag_num)
	local specialTotalWeight, specialRandomDesk
	if num == 10 then
		specialTotalWeight, specialRandomDesk = getRandomDesk(3, lucky_bag_num)
		if not specialTotalWeight or not specialRandomDesk or table.empty(specialRandomDesk) then
			specialTotalWeight = totalWeight
			specialRandomDesk = randomDesk
		end
	end
	-- dump(randomDesk)

	local awards = {}
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	for i=1,num do
		if i == 10 then
			totalWeight = specialTotalWeight
			randomDesk = specialRandomDesk
		end
		assert(totalWeight > 1, "totalWeight:"..totalWeight)
		local luckyNum = math.rand(1, totalWeight)
		local luckyInfo
		for _,otherLuckyBagVO in ipairs(randomDesk) do
			luckyNum = luckyNum - otherLuckyBagVO.weight
			if luckyNum <= 0 then
				luckyInfo = otherLuckyBagVO
				break
			end
		end
		local awardInfo = luckyInfo.award or {}

		local sendStatus = luckyBagConst.sendStatus.inHandle
		if awardInfo.gunId then
			resCtrl.addGun(roleId, awardInfo.gunId, logConst.luckyBagGet, awardInfo.time)
			sendStatus = luckyBagConst.sendStatus.done
		elseif awardInfo.goodsId then
			resCtrl.send(roleId, awardInfo.goodsId, awardInfo.amount, logConst.luckyBagGet)
			sendStatus = luckyBagConst.sendStatus.done
		end
		awards[#awards+1] = luckyInfo.id

		local record = {
			goodsType = luckyInfo.type,
			showFlag = (luckyInfo.lucky_msg == 1),
			goodsName = luckyInfo.content,
			nickname = roleInfo.nickname,
			prizeId = awardInfo.prizeId,
			status = sendStatus,
			type = type,
		}

		dbHelp.call("luckyBag.addRecord", roleId, record)
		if luckyInfo.lucky_msg == 1 then
			context.sendS2C(roleId, M_LuckyBag.handleSysBagOpen, {nickname = roleInfo.nickname, goodsName = luckyInfo.content})
		end
	end
	-- dump(awards)
	return SystemError.success, awards
end

function luckyBagCtrl.getSysRecord()
	local records = dbHelp.call("luckyBag.getRecord", _, _, true, 10)
	local result = {}
	for _,record in pairs(records) do
		result[#result+1] = {
			nickname = record.nickname,
			goodsName = record.goodsName,
			time = record.time,
			type = record.type or 2,
		}
	end
	
	local RobotLuckyRecordList = context.callS2S(SERVICE.STATISTIC, "getRobotLuckyRecordList")
	for _,robotInfo in pairs(RobotLuckyRecordList) do
		result[#result+1] = {
			nickname = robotInfo.nickname,
			goodsName = robotInfo.goodsName,
			time = robotInfo.time,
			type = robotInfo.type or 2,
		}
	end
	table.sort(result, function(p1, p2)
			return p1.time > p2.time
		end)
	local recordList = {}
	for _,info in pairs(result) do
		table.insert(recordList, {nickname = info.nickname, goodsName = info.goodsName, type = info.type})
		if #recordList >= 10 then
			break
		end
	end
	-- dump(recordList)
	return recordList
end

function luckyBagCtrl.getSelfRecord(roleId)
	local records = dbHelp.call("luckyBag.getRecord", roleId, _, _, 10)
	local result = {}
	for _,record in pairs(records) do
		result[#result+1] = {
			nickname = record.nickname,
			goodsName = record.goodsName,
			type = record.type or 2,
		}
	end
	return result
end

function luckyBagCtrl.getGoodsRecord(roleId)
	local records = dbHelp.call("luckyBag.getRecord", roleId, luckyBagConst.goodsType.real, _, 50)
	local result = {}
	for _,record in pairs(records) do
		result[#result+1] = {
			goodsName = record.goodsName,
			time = record.time,
			status = record.status,
		}
	end
	return result
end

function luckyBagCtrl.getInfo(roleId)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	local bagNum = roleInfo.bag or 0
	local sysRecords = luckyBagCtrl.getSysRecord()
	local selfRecords = luckyBagCtrl.getSelfRecord(roleId)
	local result = {
		bagNum = bagNum,
		sysRecords = sysRecords,
		selfRecords = selfRecords,
	}
	return result
end

return luckyBagCtrl