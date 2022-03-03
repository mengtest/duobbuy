local goldGunCtrl = {}
local goldGunConst = require("gold_gun.gold_gun_const")
local context = require('common.context')
local dbHelp = require("common.db_help")
local configDb = require("config.config_db")
local goldGunConfig = configDb.gold_gun_config
local goldGunPool = configDb.gold_gun_pool
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

function goldGunCtrl.getInfo(roleId)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	local goldGunPrize = roleInfo.goldGunPrize or 0
	return SystemError.success, math.floor(goldGunPrize)
end

function goldGunCtrl.lottery(roleId, level)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	local goldGunPrize = roleInfo.goldGunPrize or 0

	local pool = goldGunPool[level].pool
	if goldGunPrize < pool then
		return GoldGunError.prizeNotEnough
	end

	local randList = goldGunConfig[level]

	local randInfo = getRandInfo(randList)
	local goodsList = {}
	local awardInfo = randInfo.award or {}
	local sendStatus = goldGunConst.sendStatus.inHandle
	if awardInfo.gunId or awardInfo.goodsId then
		table.insert(goodsList,awardInfo)
		sendStatus = goldGunConst.sendStatus.done
	end

	local record = {
		goodsType = randInfo.type,
		goodsName = randInfo.content,
		nickname = roleInfo.nickname,
		prizeId = awardInfo.prizeId,
		status = sendStatus,
	}

	dbHelp.send("goldGun.addRecord", roleId, record)
	if randInfo.notice == 1 then
		context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 22, words = {roleInfo.nickname, randInfo.content}})
	end
	roleCtrl.addGoldGunPrize(roleId, -pool)

	resCtrl.sendList(roleId, goodsList, logConst.goldGunPrizeGet)

	return SystemError.success, randInfo.id
end

--获取我的奖品
function goldGunCtrl.getGoodsRecords(roleId)

	local records = dbHelp.call("relic.getRecord", roleId, goldGunConst.goodsType.real, 10)
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

return goldGunCtrl