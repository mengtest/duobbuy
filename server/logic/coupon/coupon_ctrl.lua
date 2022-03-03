local skynet = require("skynet")
local context = require("common.context")
local roleCtrl = require("role.role_ctrl")
local resOp = require("common.res_operate")
local dbHelp = require("common.db_help")

local roleEvent = require("role.role_event")

local couponConst = require("coupon.coupon_const")
local AwardState = couponConst.AwardState

local configDb = require("config.config_db")
local activityTotalConfig = configDb.activity
local activityConf = activityTotalConfig[couponConst.ACTIVITY_ID]
local couponConfig = configDb.coupon_config
local couponAward = configDb.coupon_award
local couponRecharge = configDb.coupon_recharge

local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityStatus = require("activity.activity_const").activityStatus
local activityTimeConst = require("activity.activity_const").activityTime

local logConst = require("game.log_const")
local roleConst = require("role.role_const")

local couponCtrl = {}

local function randCard(group, excludes)
	local totalWeight = 0
	local items = {}
	for _, item in ipairs(couponConfig) do
		if item.group == group then
			if not excludes[tostring(item.id)] then
				totalWeight = totalWeight + item.weight
				items[#items + 1] = item
			end
		end
	end
	local weight = 0
	for _, item in ipairs(items) do
		weight = weight + item.weight
		if math.rand(1, totalWeight) <= weight then
			return item
		end
	end
end

function couponCtrl.getInfo(roleId)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.coupon)
	if not flag then
		return ActivityError.notOpen
	end
	local info = dbHelp.call("coupon.getInfo", roleId, round)
	info.chargeMoney = info.chargeMoney or 0
	info.joinTimes = info.joinTimes or 0
	info.cards = info.cards or {}
	info.awardStates = info.awardStates or {}
	info.excludes = info.excludes or {}

	local index = math.min(#couponRecharge, table.lowerBound(couponRecharge, info.chargeMoney, "amount"))
	local conf = couponRecharge[index]
	if conf.amount > info.chargeMoney then
		info.leftTimes = index - info.joinTimes - 1
		info.needCharge = conf.amount - info.chargeMoney
	else
		info.leftTimes = index - info.joinTimes
		local nextConf = couponRecharge[index + 1]
		info.needCharge = nextConf and (nextConf.amount - info.chargeMoney) or 0
	end
	
	return SystemError.success, info, round
end

function couponCtrl.getAward(roleId, index)
	local flag, round = activityTimeCtrl.getRound(activityTimeConst.coupon)
	if not flag then
		return ActivityError.notOpen
	end
	
	local awardStates = dbHelp.call("coupon.getAwardStates", roleId, round) or {}
	local awardState
	for _, item in pairs(awardStates) do
		if item.index == index then
			awardState = item
			break
		end
	end
	if not awardState then
		return CouponError.cannotGet
	end
	if awardState.state == AwardState.GOT then
		return CouponError.hadGot
	end

	local conf = couponAward[index]
	if conf.award.goodsId then
		resOp.send(roleId, conf.award.goodsId, conf.award.amount, logConst.couponGet)
	elseif conf.award.gunId then
		resOp.addGun(roleId, conf.award.gunId, logConst.couponGet, conf.award.time)
	end

	awardState.state = AwardState.GOT

	dbHelp.send("coupon.updateAwardStates", roleId, round, awardStates)


	return SystemError.success
end

function couponCtrl.openCard(roleId, pos)
	local ec, info, round = couponCtrl.getInfo(roleId)
	if ec ~= SystemError.success then
		return ec
	end

	if info.leftTimes < 1 then
		return CouponError.notLeftTimes
	end

	for _, card in pairs(info.cards) do
		if card.pos == pos then
			return CouponError.isOpen
		end
	end

	local group = couponRecharge[info.joinTimes + 1].group
	local selected = randCard(group, info.excludes)

	info.cards[#info.cards + 1] = {pos = pos, type = selected.type}

	local cardNum = 0
	for _, card in pairs(info.cards) do
		if card.type == selected.type then
			cardNum = cardNum + 1
		end
	end

	for index, item in ipairs(couponAward) do
		if item.type == selected.type and item.num == cardNum then
			if not info.awardStates then
				info.awardStates = {}
			end
			info.awardStates[#info.awardStates + 1] = {index = index, state = AwardState.UNGET}
			break
		end
	end

	info.excludes[tostring(selected.id)] = true

	info.joinTimes = info.joinTimes + 1
	info.leftTimes = info.leftTimes - 1
	dbHelp.send("coupon.openCard", roleId, round, info)

	return SystemError.success, selected.type
end

function couponCtrl.onLogin(roleId)
end

return couponCtrl