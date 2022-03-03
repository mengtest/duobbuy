-- telnet 127.0.0.1 5056
-- inject :06000010 ./logic/update/charge_fix.lua

-- inject :0600000a ./logic/update/charge_fix.lua
-- inject :0600000b ./logic/update/charge_fix.lua
-- inject :0600000c ./logic/update/charge_fix.lua
-- inject :0600000d ./logic/update/charge_fix.lua

local dbHelp = require("common.db_help")
local hotfix = require("common.hotfix")
local roleConst = require("role.role_const")
local context = require("common.context")
local logConst   = require("game.log_const")
local logger = require("log")
local skynet = require("skynet")
local chargeConst = require("charge.charge_const")
local shopBagRate = chargeConst.shopBagRate
local configUpdater = require("update.config_updater")

local chargeOpRecord = skynet.getenv("chargeOpRecord")

local chargeCtrl = require("charge.charge_ctrl")

local recordOp = hotfix.getupvalue(chargeCtrl.sendList, "recordOp")

local chargeCtrl = require("charge.charge_ctrl")
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

-- ******************修改商城表******************
local codecache = require("skynet.codecache")
codecache.clear()

local shopConfig = hotfix.getupvalue(chargeCtrl.sendList, "shopConfig")
package.loaded["config.shop"] = nil
shopConfig = require("config.shop")
dump(shopConfig[106])
hotfix.setupvalue(chargeCtrl.sendList, "shopConfig", shopConfig)
-- ********************************************


-- -- 玩家充值
-- function chargeCtrl.chargeMoney(roleId, shopItemIndex)
-- 	local shopItemInfo = shopConfig[shopItemIndex]
-- 	if not shopItemInfo then
-- 		return
-- 	end
-- 	local goldAmount = chargeCtrl.sendList(roleId, shopItemIndex)
-- 	local shopInfo = {
-- 		shopItemIndex = shopItemIndex,
-- 		cTime = os.time(),
-- 		price = shopItemInfo.price,
-- 		name = shopItemInfo.name
-- 	}
-- 	local isFirstFlag = not chargeCtrl.isUseJoinType(roleId)
-- 	local flag = not chargeCtrl.isUseJoinType(roleId, shopItemIndex)
-- 	chargeCtrl.recordCharge(roleId, shopInfo)
-- 	chargeCtrl.recordActivity(roleId, shopItemInfo.price)
-- 	chargeCtrl.addBoxOpenNum(roleId, shopItemInfo)
-- 	context.sendS2C(roleId, M_Role.handleChargeSuccess, {shopIndex = shopItemIndex, isFirst = flag, goldAmount = goldAmount})
-- 	chargeCtrl.setRoleStatus(roleId, shopItemInfo.price)
-- 	if isFirstFlag then
-- 		chargeCtrl.sendGoods(roleId, chargeConst.fistPayAward, logConst.chargeSend)
-- 		local nickname = dbHelp.call("role.getAttrVal", roleId, "nickname")
-- 		context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 7, words = {nickname}})
-- 	end
-- 	return SystemError.success, shopInfo
-- end

-- -- 发放资源
-- function chargeCtrl.sendList(roleId, shopItemIndex)
-- 	local opSec = os.time()

-- 	recordOp(opSec, roleId, shopItemIndex, "start sendList")
-- 	local shopItemInfo = shopConfig[shopItemIndex]
-- 	if not shopItemInfo then
-- 		return
-- 	end
-- 	local goods = shopItemInfo.goods
-- 	if not goods then
-- 		return
-- 	end

-- 	recordOp(opSec, roleId, shopItemIndex, "pass check")
-- 	local goldAwardAmount
-- 	local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
-- 	if agentAdress then
-- 		recordOp(opSec, roleId, shopItemIndex, "find agent")
-- 		if shopItemInfo.goodsAwardType == roleConst.SHOP_MATERIAL then
-- 			context.callS2S(agentAdress, "doResOperate", "send", roleId, goods.goodsId, goods.amount, logConst.chargeGet, shopItemInfo.price)
-- 			if not chargeCtrl.isUseJoinType(roleId, shopItemIndex) then
-- 				local firstBuyAward = shopItemInfo.firstBuy
-- 				if firstBuyAward then
-- 					context.callS2S(agentAdress, "doResOperate", "send", roleId, goods.goodsId, firstBuyAward.amount, logConst.chargeSend, shopItemInfo.price)
-- 				end
-- 			end
-- 		elseif shopItemInfo.goodsAwardType == roleConst.SHOP_GUN then
-- 			context.callS2S(agentAdress, "doResOperate", "addGun", roleId, goods.gunId, logConst.chargeGet, goods.time)
-- 		elseif shopItemInfo.goodsAwardType == roleConst.SHOP_GIFT then
-- 			for _, award in pairs(goods) do
-- 				if award.goodsId then
-- 					context.callS2S(agentAdress, "doResOperate", "send", roleId, award.goodsId, award.amount, logConst.chargeGet)
-- 				elseif award.gunId then
-- 					context.callS2S(agentAdress, "doResOperate", "addGun", roleId, award.gunId, logConst.chargeGet, award.time)
-- 				end
-- 			end
-- 		elseif shopItemInfo.goodsAwardType == roleConst.SHOP_BAG then
-- 			context.callS2S(agentAdress, "doResOperate", "send", roleId, goods.goodsId, goods.amount, logConst.chargeGet)
-- 			goldAwardAmount = goods.amount
-- 			if not chargeCtrl.isUserJoinBag(roleId, shopItemIndex) then
-- 				local rateIndex = math.rand(1,#shopBagRate)
-- 				local bagRetNum = math.floor(shopBagRate[rateIndex] * goods.amount)
-- 				context.callS2S(agentAdress, "doResOperate", "send", roleId, goods.goodsId, bagRetNum, logConst.chargeGet)
-- 				chargeCtrl.recordShopBag(roleId, shopItemIndex)
-- 				goldAwardAmount = goldAwardAmount + bagRetNum
-- 			end
-- 		end
-- 		recordOp(opSec, roleId, shopItemIndex, "online send over")
-- 	else
-- 		recordOp(opSec, roleId, shopItemIndex, "not find agent")
-- 		if shopItemInfo.goodsAwardType == roleConst.SHOP_MATERIAL then
-- 			chargeCtrl.sendOffLine(roleId, goods)
-- 			if not chargeCtrl.isUseJoinType(roleId, shopItemIndex) then
-- 				local firstBuyAward = shopItemInfo.firstBuy
-- 				chargeCtrl.sendOffLine(roleId, firstBuyAward)
-- 			end
-- 		elseif shopItemInfo.goodsAwardType == roleConst.SHOP_GUN then
-- 			chargeCtrl.sendOffLine(roleId, goods)
-- 		elseif shopItemInfo.goodsAwardType == roleConst.SHOP_GIFT then
-- 			for _,award in pairs(goods) do
-- 				chargeCtrl.sendOffLine(roleId, award)
-- 			end
-- 		elseif shopItemInfo.goodsAwardType == roleConst.SHOP_BAG then
-- 			chargeCtrl.sendOffLine(roleId, goods)
-- 			goldAwardAmount = goods.amount
-- 			if not chargeCtrl.isUserJoinBag(roleId, shopItemIndex) then
-- 				local rateIndex = math.rand(1,#shopBagRate)
-- 				local bagRetNum = math.floor(shopBagRate[rateIndex] * goods.amount)
-- 				local bagRetAward = {goodsId = goods.goodsId, amount = bagRetNum}
-- 				chargeCtrl.sendOffLine(roleId, bagRetAward)
-- 				chargeCtrl.recordShopBag(roleId, shopItemIndex)
-- 				goldAwardAmount = goldAwardAmount + bagRetNum
-- 			end
-- 		end
-- 		recordOp(opSec, roleId, shopItemIndex, "offline send over")
-- 	end

-- 	recordOp(opSec, roleId, shopItemIndex, "end sendList")
-- 	return goldAwardAmount
-- end

print("------------------ok")