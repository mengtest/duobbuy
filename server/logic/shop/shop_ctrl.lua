local context = require("common.context")
local shopGiftConfig = require("config.shop_gift")
local shopGoldConfig = require("config.shop_gold")
local shopBagConfig = require("config.shop_bag")
local dbHelp = require("common.db_help")
local shopCtrl = {}

function shopCtrl.getGiftShopInfo(roleId)
	local goldIds, giftIds, bagIds = {}, {}, {}
	for _,conf in pairs(shopGoldConfig) do
		goldIds[#goldIds+1] = conf.id
	end
	for _,conf in pairs(shopGiftConfig) do
		giftIds[#giftIds+1] = conf.id
	end
	for _,conf in pairs(shopBagConfig) do
		bagIds[#bagIds+1] = conf.id
	end

	local goldStatus, giftStatus, bagStatus = context.callS2S(SERVICE.CHARGE, "getUseJoinTypes", roleId, goldIds, giftIds, bagIds)

	local result = {gold = goldStatus, gift = giftStatus, bag = bagStatus}
	return result
end

function shopCtrl.getMonthCardDays(roleId)
	return dbHelp.call("charge.getMonthCardDays",roleId)
end

function shopCtrl.getGiftInfoList(roleId)
	local giftInfoIndex = dbHelp.call("charge.getGiftInfoIndex",roleId)
	local giftInfoList = {}
	for giftId,days in pairs(giftInfoIndex) do
		if days > 0 then
			table.insert(giftInfoList, {giftId = giftId, days = days})
		end
	end
	return giftInfoList
end

return shopCtrl