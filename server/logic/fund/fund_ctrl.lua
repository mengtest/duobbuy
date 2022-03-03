local resOperate = require("common.res_operate")
local json = require("json")
local logger  	= require("log")
local roleCtrl = require("role.role_ctrl")
local mobileCtrl = require("mobile.mobile_ctrl")

local taskCtrl = require("task.task_ctrl")
local TaskType = require("task.task_const").TaskType

local roleConst = require("role.role_const")
local logConst = require("game.log_const")
local context = require("common.context")
local fundCtrl = {}
local fundConst = require("fund.fund_const")

function fundCtrl.onLogin(roleId)
	local fundRecordInfo = context.callS2S(SERVICE.STATISTIC, "getFundInfo")
	-- dump(fundRecordInfo)
	context.sendS2C(roleId, M_Fund.onSyncFundRecord, fundRecordInfo)
end

function fundCtrl.join(roleId, itemId, round, joinNum)
	if joinNum <= 0 then
		return GameError.treasureNotEnough
	end
	local ec = resOperate.isResEnough(roleId, roleConst.TREASURE_ID, joinNum)
	if ec ~= SystemError.success then
		return ec
	end

	if mobileCtrl.needLockMobile(roleId) then 
		return RoleError.mobileNotLock
	end

	resOperate.costTreasure(roleId, joinNum, logConst.fundCost)

	local roleInfo = roleCtrl.getRoleInfo(roleId)

	local data = {
		method = "roleJoinSecKill",
		roleId = roleId,
		itemId = itemId,
		killNum = joinNum,
		nickname = roleInfo.nickname,
		round = round,
	}
	-- dump(data)
	local success, result = fundCtrl.centerRequest(data)
	-- print("success:",success)
	-- dump(result)
	local totalJoinNum 
	if result and result.data and result.data.totalJoinNum then 
		totalJoinNum = result.data.totalJoinNum
	end 
	if not success then
		logger.Errorf("fundCtrl.join(roleId:%s, itemId:%s, round:%s, joinNum:%s) result:%s", roleId, itemId, round, joinNum, dumpString(result))
		if result and result.errorCode then
			roleCtrl.addRes(roleId, roleConst.TREASURE_ID, joinNum, logConst.fundCost)
			local ec = fundConst.errors[result.errorCode]
			if ec then
				return ec, totalJoinNum
			end
		end
		return FundError.serverError, totalJoinNum
	end
	
	taskCtrl.incrTaskStep(roleId, TaskType.FundJoin, 1)
	return SystemError.success, totalJoinNum
end

function fundCtrl.exchange(roleId, itemId)
	if mobileCtrl.needLockMobile(roleId) then 
		return RoleError.mobileNotLock
	end
	
	local data = {
		method = "getExchangePrice",
		itemId = itemId,
	}
	-- dump(data)
	local success, result = fundCtrl.centerRequest(data)
	-- dump(result)
	if not success then
		return FundError.serverError
	end
	local httpData = result.data
	local price = httpData.price
	local cost = httpData.cost
	local itemType = httpData.type
	assert(price > 0, "fundCtrl.exchange price error: " .. price)
	local ec = resOperate.isResEnough(roleId, roleConst.TREASURE_ID, price)
	if ec ~= SystemError.success then
		return ec
	end
	if itemType == fundConst.itemType.GUN then
		local roleInfo = roleCtrl.getRoleInfo(roleId)		
		if table.find(roleInfo.guns, cost) then
			return FundError.gunExist
		end
	end

	resOperate.costTreasure(roleId, price, logConst.exchangeCost)

	data = {
		method = "roleJoinExchange",
		itemId = itemId,
		roleId = roleId,
		price = price,
	}
	local joinSuccess, joinRes = fundCtrl.centerRequest(data)
	-- dump(joinRes)
	if not joinSuccess then
		logger.Info("roleJoinExchange:" .. roleId .. "," .. price)
		roleCtrl.addRes(roleId, roleConst.TREASURE_ID, price, logConst.exchangeCost)
		if result and joinRes.errorCode then
			local ec = fundConst.errors[joinRes.errorCode]
			if ec then
				return ec
			end
		end
		return FundError.serverError
	end
	
	if itemType == fundConst.itemType.GAME and cost > 0 then
		resOperate.send(roleId, roleConst.GOLD_ID, cost, logConst.exchangeGet)
	end
	if itemType == fundConst.itemType.GUN and cost > 0 then
		resOperate.addGun(roleId, cost, logConst.exchangeGet)
		context.sendS2C(roleId, M_Role.handleChargeSuccess, {shopIndex = cost, isFirst = true})
	end
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	-- context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 2, words = {roleInfo.nickname, price, result.data.title}})
	return SystemError.success
end

function fundCtrl.centerRequest(data)
	local result = context.callS2S(SERVICE.RECORD, "callDataToCenter", data)
	if not result then
		return true
	end
	result = json.decode(result)
	if not result then
		return true
	end
	local success = false
	if result and result.errorCode == 0 then
		success = true
	end
	return success, result
end

return fundCtrl