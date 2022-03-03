local dbHelp = require("common.db_help")
local roleConst = require("role.role_const")
local context = require("common.context")
local logConst   = require("game.log_const")
local logger = require("log")
local skynet = require("skynet")
local shopConfig = require("config.shop")
local materialConfig = require("config.material")
local gunConf = require("config.gun")
local chargeConst = require("charge.charge_const")
local shopBagRate = chargeConst.shopBagRate
local language 	= require("language.language")
local activityTotalConfig = require("config.activity_config")
local GiftConfig = require("config.gift")
local fruitConst = require("fruit.fruit_const")
local fruitActivityId = fruitConst.activityId
local diskActivityId = require("charge_disk.charge_disk_const").activityId

local fruitActivityConf = activityTotalConfig[fruitActivityId]
local diskActivityConf = activityTotalConfig[diskActivityId]

local rechargeActivityConf = require("config.recharge_activity")
local activityConst = require("activity.activity_const")
local dailyActivityId = activityConst.dailyActivityId
local roundActivityId = activityConst.roundActivityId
local activityOpenFlag = true

local activityTimeConst = activityConst.activityTime
local activityStatus = activityConst.activityStatus

local chargeOpRecord = skynet.getenv("chargeOpRecord")
local inviteConst = require("invite.invite_const")

local chargeCtrl = {}

-- 记录金币充值log(离线状态下)
local function recordOfflineGoldLog(roleId, amount, curValue, source)
	local startSec = skynet.time()
	local endSec = startSec
	local source = source or logConst.chargeGet
	local step = source .. "," .. amount .. "," .. 1 
	local stepInfo = {{step}}
	local logInfo = {
		roleId = roleId,
		changeVal = amount,
		source = source,
		curValue = curValue,
		startSec = startSec,
		endSec = endSec,
		goodsId = roleConst.GOLD_ID,
		stepInfo = stepInfo,
	}
	local date = os.date("%Y%m%d")
	logger.Game("gold_log_" .. date, logInfo)
end

local function recordOp(sec, roleId, shopItemIndex, flag)
	if chargeOpRecord then
		dbHelp.send("charge.recordOp", sec, roleId, shopItemIndex, flag)
	end
end


local function recordGiftDays(roleId, giftId)
	if not roleId or not giftId then
		logger.Errorf("recordGiftDays(roleId, giftId)")
		return
	end
	roleId = tonumber(roleId)
	giftId = tonumber(giftId)
	if giftId == 0 then
		logger.Errorf("recordGiftDays(roleId, giftId) roleId:"..roleId.." giftId:"..giftId)
		return
	end
	local GiftVO = GiftConfig[giftId]
	if not GiftVO then
		logger.Errorf("recordGiftDays(roleId, giftId) roleId:"..roleId.." giftId:"..giftId)
		return
	end
	local days = GiftVO.days
	if days <= 0 then
		logger.Errorf("recordGiftDays(roleId, giftId) roleId:"..roleId.." giftId:"..giftId.." days:"..days)
		return
	end
	dbHelp.send('charge.incryGiftDays', roleId, giftId, days)
end

--记录玩家月卡天数
local function recordMonthCardDays(roleId)
	local days = dbHelp.call('charge.getMonthCardDays',roleId)
	if days then
		dbHelp.send('charge.incryMonthCardDays',roleId,chargeConst.monthCardDays)
	else
		dbHelp.send('charge.setMonthCardDays',roleId,chargeConst.monthCardDays)
	end
end


-- 玩家充值
function chargeCtrl.chargeMoney(roleId, shopItemIndex)
	local shopItemInfo = shopConfig[shopItemIndex]
	if not shopItemInfo then
		return
	end
	local goldAmount = chargeCtrl.sendList(roleId, shopItemIndex)
	local shopInfo = {
		shopItemIndex = shopItemIndex,
		cTime = os.time(),
		price = shopItemInfo.price,
		name = shopItemInfo.name
	}
	local isFirstFlag = not chargeCtrl.isUseJoinType(roleId)
	local flag = not chargeCtrl.isUseJoinType(roleId, shopItemIndex)
	chargeCtrl.recordCharge(roleId, shopInfo)
	chargeCtrl.recordActivity(roleId, shopItemInfo.price)
	chargeCtrl.addBoxOpenNum(roleId, shopItemInfo)
	context.sendS2C(roleId, M_Role.handleChargeSuccess, {shopIndex = shopItemIndex, isFirst = flag, goldAmount = goldAmount})
	chargeCtrl.setRoleStatus(roleId, shopItemInfo.price)
	if isFirstFlag then
		-- -- 首充奖励通过邮件发送
		-- local fistPayAwardAttach = {}
		-- for _,award in ipairs(chargeConst.fistPayAward or {}) do
		-- 	table.insert(fistPayAwardAttach, {goodsId = award.goodsId, amount = award.amount, gunId = award.gunId, time = award.time})
		-- end
		-- if not table.empty(fistPayAwardAttach) then
		-- 	context.sendS2S(SERVICE.MAIL, "sendMail", roleId, 
		-- 		{
		-- 			mailType = 1, 
		-- 			pageType = 1, 
		-- 			source = logConst.chargeSend, 
		-- 			attach = fistPayAwardAttach, 
		-- 			title = language("首充奖励"), 
		-- 			content = language("恭喜您完成了首次充值，请领取以下奖励...")
		-- 		})
		-- end

		chargeCtrl.sendGoods(roleId, chargeConst.fistPayAward, logConst.chargeSend)
		local nickname = dbHelp.call("role.getAttrVal", roleId, "nickname")
		context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 7, words = {nickname}})
	end
	return SystemError.success, shopInfo
end

-- 玩家是否参与过某类充值
function chargeCtrl.isUseJoinType(roleId, shopItemIndex)
	return dbHelp.call("charge.hasRoleIndexReocrd", roleId, shopItemIndex) and true or false
end

-- 玩家是否参与过福袋
function chargeCtrl.isUserJoinBag(roleId, shopItemIndex)
	local date = os.date("%Y%m%d")
	return dbHelp.call("charge.hasRoleShopBag", roleId, shopItemIndex, date) and true or false
end

-- 记录玩家参与福袋
function chargeCtrl.recordShopBag(roleId, shopItemIndex)
	local date = os.date("%Y%m%d")
	return dbHelp.call("charge.recordShopBag", roleId, shopItemIndex, date)
end

-- 记录玩家充值
function chargeCtrl.recordCharge(roleId, shopInfo)
	dbHelp.call("charge.recordCharge", roleId, shopInfo)
end

-- 获取玩家充值金钱总量(money)
function chargeCtrl.getTotalPriceByTime(roleId, sTime, eTime)
	return dbHelp.call("charge.getRoleChargeAmount", roleId, sTime, eTime)
end

-- 发放资源
function chargeCtrl.sendList(roleId, shopItemIndex)
	local opSec = os.time()

	recordOp(opSec, roleId, shopItemIndex, "start sendList")
	local shopItemInfo = shopConfig[shopItemIndex]
	if not shopItemInfo then
		return
	end
	local goods = shopItemInfo.goods
	if not goods then
		return
	end

	-- 记录大礼包
	if shopItemInfo.gift_id and type(shopItemInfo.gift_id) == "number" and shopItemInfo.gift_id ~= 0 then
		recordGiftDays(roleId, shopItemInfo.gift_id)
	end

	recordOp(opSec, roleId, shopItemIndex, "pass check")
	local goldAwardAmount
	local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
	if agentAdress then
		recordOp(opSec, roleId, shopItemIndex, "find agent")
		if shopItemInfo.goodsAwardType == roleConst.SHOP_MATERIAL then
			for _, award in pairs(goods) do
				if award.goodsId then
					context.callS2S(agentAdress, "doResOperate", "send", roleId, award.goodsId, award.amount, logConst.chargeGet,shopItemInfo.price)
				elseif award.gunId then
					context.callS2S(agentAdress, "doResOperate", "addGun", roleId, award.gunId, logConst.chargeGet, award.time)
				end
			end
			if not chargeCtrl.isUseJoinType(roleId, shopItemIndex) then
				local firstBuyAward = shopItemInfo.firstBuy or {}
				if not table.empty(firstBuyAward) then
					for _, award in pairs(firstBuyAward) do
						if award.goodsId then
							context.callS2S(agentAdress, "doResOperate", "send", roleId, award.goodsId, award.amount, logConst.chargeSend,shopItemInfo.price)
						elseif award.gunId then
							context.callS2S(agentAdress, "doResOperate", "addGun", roleId, award.gunId, logConst.chargeSend, award.time)
						end
					end
				end
			end
			if shopItemInfo.goodId == chargeConst.monthCardFlag then
				recordMonthCardDays(roleId)
			end
		elseif shopItemInfo.goodsAwardType == roleConst.SHOP_GUN then
			context.callS2S(agentAdress, "doResOperate", "addGun", roleId, goods.gunId, logConst.chargeGet, goods.time)
		elseif shopItemInfo.goodsAwardType == roleConst.SHOP_GIFT then
			for _, award in pairs(goods) do
				if award.goodsId then
					context.callS2S(agentAdress, "doResOperate", "send", roleId, award.goodsId, award.amount, logConst.chargeGet)
				elseif award.gunId then
					context.callS2S(agentAdress, "doResOperate", "addGun", roleId, award.gunId, logConst.chargeGet, award.time)
				end
			end
		elseif shopItemInfo.goodsAwardType == roleConst.SHOP_BAG then
			context.callS2S(agentAdress, "doResOperate", "send", roleId, goods.goodsId, goods.amount, logConst.chargeGet)
			goldAwardAmount = goods.amount
			if not chargeCtrl.isUserJoinBag(roleId, shopItemIndex) then
				local rateIndex = math.rand(1,#shopBagRate)
				local bagRetNum = math.floor(shopBagRate[rateIndex] * goods.amount)
				context.callS2S(agentAdress, "doResOperate", "send", roleId, goods.goodsId, bagRetNum, logConst.chargeGet)
				chargeCtrl.recordShopBag(roleId, shopItemIndex)
				goldAwardAmount = goldAwardAmount + bagRetNum
			end
		end
		recordOp(opSec, roleId, shopItemIndex, "online send over")
	else
		recordOp(opSec, roleId, shopItemIndex, "not find agent")
		if shopItemInfo.goodsAwardType == roleConst.SHOP_MATERIAL then
			for _,award in pairs(goods) do
				chargeCtrl.sendOffLine(roleId, award, logConst.chargeGet)
			end
			if not chargeCtrl.isUseJoinType(roleId, shopItemIndex) then
				local firstBuyAward = shopItemInfo.firstBuy or {}
				if not table.empty(firstBuyAward) then
					for _,award in pairs(firstBuyAward) do
						chargeCtrl.sendOffLine(roleId, award, logConst.chargeSend)
					end
				end
			end
			--月卡逻辑
			if shopItemInfo.goodId == chargeConst.monthCardFlag then
				recordMonthCardDays(roleId)
			end
		elseif shopItemInfo.goodsAwardType == roleConst.SHOP_GUN then
			chargeCtrl.sendOffLine(roleId, goods)
		elseif shopItemInfo.goodsAwardType == roleConst.SHOP_GIFT then
			for _,award in pairs(goods) do
				chargeCtrl.sendOffLine(roleId, award)
			end
		elseif shopItemInfo.goodsAwardType == roleConst.SHOP_BAG then
			chargeCtrl.sendOffLine(roleId, goods)
			goldAwardAmount = goods.amount
			if not chargeCtrl.isUserJoinBag(roleId, shopItemIndex) then
				local rateIndex = math.rand(1,#shopBagRate)
				local bagRetNum = math.floor(shopBagRate[rateIndex] * goods.amount)
				local bagRetAward = {goodsId = goods.goodsId, amount = bagRetNum}
				chargeCtrl.sendOffLine(roleId, bagRetAward)
				chargeCtrl.recordShopBag(roleId, shopItemIndex)
				goldAwardAmount = goldAwardAmount + bagRetNum
			end
		end
		recordOp(opSec, roleId, shopItemIndex, "offline send over")
	end

	recordOp(opSec, roleId, shopItemIndex, "end sendList")
	return goldAwardAmount
end

-- 充值发放物品
function chargeCtrl.sendGoods(roleId, goodsList, source)
    roleId = tonumber(roleId)
	local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
	if agentAdress then
		context.callS2S(agentAdress, "doResOperate", "sendList", roleId, goodsList, source)
	else
		for _,award in pairs(goodsList) do
			chargeCtrl.sendOffLine(roleId, award, source)
		end
	end
end

--发送炮塔
function chargeCtrl.sendGun(roleId, gunId, time, source)
	local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
	if agentAdress then
		context.callS2S(agentAdress, "doResOperate", "addGun", roleId, gunId, source, time)
	else
		local gunInfo = gunConf[gunId]
		if gunInfo then
			dbHelp.call("role.setAttrVal", roleId, "gun", gunId)
			local guns = dbHelp.call("role.getAttrVal", roleId, "guns")
			if not table.find(guns, gunId) then
				guns[#guns+1] = gunId
				dbHelp.call("role.setAttrVal", roleId, "guns", guns)
			end
		end
		if time then
			local gunAgeInfo = dbHelp.call("activity.getGunEndInfo", roleId)
			local gunEndTime = gunAgeInfo[tostring(gunId)]
			if gunEndTime then
				dbHelp.send("activity.incrGunEndTime", roleId, gunId, time)
			else
				local endSec = os.time() + time
				dbHelp.send("activity.setGunEndTime", roleId, gunId, endSec)
			end
		end
	end
end

-- 离线发送物品
function chargeCtrl.sendOffLine(roleId, award, source)
	if award.goodsId then
		local attrName = materialConfig[award.goodsId].attrName
		if attrName then
			dbHelp.call("role.incrAttrVal", roleId, attrName, award.amount)
			if attrName == "gold" then
				local goldNum = dbHelp.call("role.getAttrVal", roleId, "gold")
				recordOfflineGoldLog(roleId, award.amount, goldNum, source)
				if not source or ( source ~= logConst.dailyRechargeGet 
						and source ~= logConst.roundRechargeGet 
						and source ~= logConst.chargeSend) then
					local notFishGold = dbHelp.call("role.getAttrVal", roleId, "notFishGold")
					dbHelp.call("role.incrAttrVal", roleId, "notFishGold", award.amount)
				end
			end
		end
	elseif award.gunId then
		local gunId = award.gunId
		local gunInfo = gunConf[gunId]
		if gunInfo then
			dbHelp.call("role.setAttrVal", roleId, "gun", gunId)
			local guns = dbHelp.call("role.getAttrVal", roleId, "guns")
			if not table.find(guns, gunId) then
				guns[#guns+1] = gunId
				dbHelp.call("role.setAttrVal", roleId, "guns", guns)
			end
		end
		if award.time then
			local gunAgeInfo = dbHelp.call("activity.getGunEndInfo", roleId)
			local gunEndTime = gunAgeInfo[tostring(gunId)]
			if gunEndTime then
				dbHelp.send("activity.incrGunEndTime", roleId, gunId, award.time)
			else
				local endSec = os.time() + award.time
				dbHelp.send("activity.setGunEndTime", roleId, gunId, endSec)
			end
		end
	end
end

---------------------------------------------------------------------------------

local function judgeRechargeInfoFunc(sec, activityId)
	if not activityOpenFlag then
		return false
	end
	sec = sec or os.time()
	local beginTime = rechargeActivityConf[activityId].beginTime
	if sec < beginTime then
		return false
	end
	local lastTime, spaceTime = rechargeActivityConf[activityId].lastTime, rechargeActivityConf[activityId].spaceTime
	local passSec = sec - beginTime
	local round = math.ceil(passSec / (lastTime + spaceTime))
	local flagTime = passSec - (round - 1) * (lastTime + spaceTime)
	if flagTime <= lastTime then
		return true, round
	else
		return false
	end
end

local function judgeDisckFunc(sec)
	if not activityOpenFlag then
		return false
	end
	sec = sec or os.time()
	local beginTime = diskActivityConf.beginTime
	local endTime = diskActivityConf.endTime
	if sec < beginTime or sec > endTime then
		return false
	end
	local lastTime, spaceTime = diskActivityConf.lastTime, diskActivityConf.spaceTime
	local passSec = sec - beginTime
	local round = math.ceil(passSec / (lastTime + spaceTime))
	local flagTime = passSec - (round - 1) * (lastTime + spaceTime)
	if flagTime <= lastTime then
		return true, round
	else
		return false
	end
end

function chargeCtrl.setRechargeActivityStatus(status)
	activityOpenFlag = status
end

function chargeCtrl.recordActivity(roleId, price)
	local curSec = os.time()
	local curDay = os.date("%Y%m%d", curSec)
	-- 水果机

	local timeConfig = context.callS2S(SERVICE.ACTIVITY, "getActiviyTime", activityTimeConst.fruit)
	if timeConfig then
		if timeConfig.status == activityStatus.open and curSec >= timeConfig.sTime and curSec <= timeConfig.eTime then
			dbHelp.send("fruit.incrPrice", roleId, price)
		end
	else
		if curSec >= fruitActivityConf.beginTime and curSec <= fruitActivityConf.endTime then
			dbHelp.send("fruit.incrPrice", roleId, price)
		end
	end
	
	-- 充值送金币
	local dailyActivityFlag = judgeRechargeInfoFunc(curSec, dailyActivityId)
	if dailyActivityFlag then
		dbHelp.send("activity.recordDailyPrice", roleId, curDay, price)
		judgeRedFlag = true
	end
	local roundActivityFlag, round = judgeRechargeInfoFunc(curSec, roundActivityId)
	if roundActivityFlag then
		dbHelp.send("activity.recordRoundPrice", roleId, round, price)
	end
	if dailyActivityFlag or roundActivityFlag then
		local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
		if agentAdress then
			context.callS2S(agentAdress, "doModLogic", roleId, "activity.activity_ctrl", "sendRedPoint", roleId)
		end
	end
	-- 充值转盘
	local timeConfigTwo = context.callS2S(SERVICE.ACTIVITY, "getActiviyTime", activityTimeConst.chargeDisk)
	if timeConfigTwo then
		if timeConfigTwo.status == activityStatus.open and curSec >= timeConfigTwo.sTime and curSec <= timeConfigTwo.eTime then
			dbHelp.send("chargeDisk.incrChargeMoney", roleId, timeConfigTwo.round, price)
		end
	else
		local diskActivityFlag, diskRound = judgeDisckFunc(curSec)
		if diskActivityFlag then
			dbHelp.send("chargeDisk.incrChargeMoney", roleId, diskRound, price)
		end
	end

	-- 聚宝盆
	local timeConfigTwo = context.callS2S(SERVICE.ACTIVITY, "getActiviyTime", activityTimeConst.treasureBowl)
	if timeConfigTwo then
		if timeConfigTwo.status == activityStatus.open and curSec >= timeConfigTwo.sTime and curSec <= timeConfigTwo.eTime then
			dbHelp.send("treasureBowl.incrChargeMoney", roleId, timeConfigTwo.round, price)
		end
	end

	-- 刮刮乐
	local timeConfigTwo = context.callS2S(SERVICE.ACTIVITY, "getActiviyTime", activityTimeConst.coupon)
	if timeConfigTwo then
		if timeConfigTwo.status == activityStatus.open and curSec >= timeConfigTwo.sTime and curSec <= timeConfigTwo.eTime then
			dbHelp.send("coupon.incrChargeMoney", roleId, timeConfigTwo.round, price)
		end
	end

	-- 疯狂宝箱
	local timeConfigTwo = context.callS2S(SERVICE.ACTIVITY, "getActiviyTime", activityTimeConst.crazyBox)
	if timeConfigTwo then
		if timeConfigTwo.status == activityStatus.open and curSec >= timeConfigTwo.sTime and curSec <= timeConfigTwo.eTime then
			dbHelp.send("crazyBox.incrChargeMoney", roleId, timeConfigTwo.round, price)
		end
	end

	-- 每日充值
	local timeConfigTwo = context.callS2S(SERVICE.ACTIVITY, "getActiviyTime", activityTimeConst.dailyCharge)
	if timeConfigTwo then
		if timeConfigTwo.status == activityStatus.open and curSec >= timeConfigTwo.sTime and curSec <= timeConfigTwo.eTime then
			local month = os.date("%Y%m")
			local info = dbHelp.call("dailyCharge.getInfo", roleId, month)
			if not info.lastChargeDate or curDay > info.lastChargeDate then
				dbHelp.send("dailyCharge.updateChargeDays", roleId, month, curDay)
			end
		end
	end

	-- 好友邀请
	local timeConfigTwo = context.callS2S(SERVICE.ACTIVITY, "getActiviyTime", activityTimeConst.invite)
	if timeConfigTwo then
		if timeConfigTwo.status == activityStatus.open and curSec >= timeConfigTwo.sTime and curSec <= timeConfigTwo.eTime then
			local playInfo = dbHelp.call("invite.getPlayInfo", roleId)
			if playInfo and playInfo.chargeAddStatus then
				dbHelp.call("invite.addChargeNum", playInfo.inviteId, price)
				--红点检测
				local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", playInfo.inviteId)
				if agentAdress then
					local info = dbHelp.call("invite.getChargeInfo", playInfo.inviteId)
					local chargeNum = info.chargeNum or 0
					local getAmount = info.getAmount or 0
					local canGetAmount = math.floor(chargeNum/100) * inviteConst.chargeAwardNum
					if (canGetAmount - getAmount) > 0 then
						context.sendS2C(playInfo.inviteId, M_RedPoint.handleActive, {data = "Invite"})
					end
				end
			end
		end
	end

	-- 积分抽奖
	local timeConfigTwo = context.callS2S(SERVICE.ACTIVITY, "getActiviyTime", activityTimeConst.scoreLottery)
	if timeConfigTwo then
		if timeConfigTwo.status == activityStatus.open and curSec >= timeConfigTwo.sTime and curSec <= timeConfigTwo.eTime then
			dbHelp.send("scoreLottery.incrScore", roleId, timeConfigTwo.round, price)
		end
	end

	-- 砸金蛋
	local timeConfigTwo = context.callS2S(SERVICE.ACTIVITY, "getActiviyTime", activityTimeConst.egg)
	if timeConfigTwo then
		if timeConfigTwo.status == activityStatus.open and curSec >= timeConfigTwo.sTime and curSec <= timeConfigTwo.eTime then
			dbHelp.send("egg.incrChargeMoney", roleId, timeConfigTwo.round, price)
		end
	end
end

function chargeCtrl.openExchangeActivity(roleId, miscCode)
	-- print("chargeCtrl.openExchangeActivity(roleId) roleId:"..roleId.." miscCode:"..miscCode)
	-- dbHelp.call("sign.setMiscCode", roleId, miscCode)
	context.sendAgentFunc(roleId, "sign.sign_ctrl", "open", roleId, miscCode)
end

function chargeCtrl.setRoleStatus(roleId, price)
	local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
	if agentAdress then
		context.callS2S(agentAdress, "doModLogic", roleId, "role.role_ctrl", "setVip", roleId)
		context.callS2S(agentAdress, "doModLogic", roleId, "role.role_ctrl", "setChargeStatus", roleId, true)
		context.callS2S(agentAdress, "doModLogic", roleId, "role.role_ctrl", "addChargeNum", roleId, price)
	else
		local isVip = dbHelp.call("role.getAttrVal", roleId, "isVip")
		if not isVip then
			dbHelp.call("role.setAttrVal", roleId, "isVip", true)
		end
		local chargeStatus = dbHelp.call("role.getAttrVal", roleId, "chargeStatus")
		if not chargeStatus then
			dbHelp.call("role.setAttrVal", roleId, "chargeStatus", true)
		end
		dbHelp.call("role.incrAttrVal", roleId, "chargeNum", price)
	end
end

function chargeCtrl.addBoxOpenNum(roleId, conf)
	if conf.treasure then
		for id,val in ipairs(conf.treasure) do
			dbHelp.send("box.incrOpenNum", roleId, id, val)
		end
	end
end

-----------------------------------------------------------------------------

return chargeCtrl