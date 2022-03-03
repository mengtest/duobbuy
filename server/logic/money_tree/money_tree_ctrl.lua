local moneyTreeCtrl = {}

local context = require('common.context')
local dbHelp = require("common.db_help")
local configDb = require("config.config_db")
local moneyTreeConf = configDb.money_tree_config

local moneyTreeConst = require("money_tree.money_tree_const")
local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityConst = require("activity.activity_const")
local activityTimeConst = activityConst.activityTime
local roleCtrl = require("role.role_ctrl")
local roleConst = require("role.role_const")
local logConst = require("game.log_const")
local activityStatus = require("activity.activity_const").activityStatus
local resCtrl = require("common.res_operate")


function moneyTreeCtrl.getInfo(roleId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.moneyTree)
	if not flag then
		return ActivityError.notOpen
	end

	local info = context.callS2S(SERVICE.ACTIVITY, "getMoneyTreeInfo", round)
	local moneyTreeInfo = info.moneyTreeInfo
	local leftNum = info.leftNum
	local displayInfo = {}
	for _,v in pairs(moneyTreeInfo) do
		local display = moneyTreeConf[v.awardId].display
		if display > 0 then
			table.insert(displayInfo, {id = v.awardId, num = v.num})
		end
	end

	local result = {}
	result.leftNum = leftNum
	result.totalNum = moneyTreeConst.initAwardNum
	result.displayInfos = displayInfo
	-- print("result",tableToString(result))
	return SystemError.success, result
end

function moneyTreeCtrl.lottery(roleId, num)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.moneyTree)
	if not flag then
		return ActivityError.notOpen
	end

	local cost = moneyTreeConst.singleCost * num
	local ec = resCtrl.isResEnough(roleId, roleConst.TREASURE_ID, cost)
	if ec ~= SystemError.success then
		return ec
	end

	local roleInfo = roleCtrl.getRoleInfo(roleId)

	local ec, awards = context.callS2S(SERVICE.ACTIVITY, "moneyTreeLottery", round, num)
	if ec ~= SystemError.success then
		return ec
	end

	resCtrl.costTreasure(roleId, cost, logConst.moneyTreeCost)

	local goodsList = {}   --要发放的奖品
	for _,awardId in pairs(awards) do
		local conf = moneyTreeConf[awardId]

		local awardInfo = conf.award or {}
		local sendStatus = moneyTreeConst.sendStatus.inHandle
		if awardInfo.gunId or awardInfo.goodsId then
			table.insert(goodsList,awardInfo)
			sendStatus = moneyTreeConst.sendStatus.done
		end

		local record = {
			goodsType = conf.type,
			showFlag = (conf.display == 1),
			goodsName = conf.content,
			nickname = roleInfo.nickname,
			prizeId = awardInfo.prizeId,
			status = sendStatus,
			round  = round,
		}

		dbHelp.send("moneyTree.addRecord", roleId, record)
		if conf.notice == 1 then
			context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 18, words = {roleInfo.nickname, conf.content}})
		end
	end

	resCtrl.sendList(roleId, goodsList, logConst.moneyTreeGet)
	-- print("awards",tableToString(awards))
	return SystemError.success , {awards = awards}
end

--获取我的奖品
function moneyTreeCtrl.getGoodsRecords(roleId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.moneyTree)
	if not flag then
		return ActivityError.notOpen
	end
	local records = dbHelp.call("moneyTree.getRecord", roleId, round, moneyTreeConst.goodsType.real, 10)
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

return moneyTreeCtrl