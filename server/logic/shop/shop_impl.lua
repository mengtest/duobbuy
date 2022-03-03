local shopCtrl = require("shop.shop_ctrl")
local shopImpl = {}

function shopImpl.getGiftShopInfo(roleId)
	local result = shopCtrl.getGiftShopInfo(roleId)
	return SystemError.success, result
end

function shopImpl.getMonthCardDays(roleId)
	local days = shopCtrl.getMonthCardDays(roleId)
	local leftDays = days or 0
	return SystemError.success, leftDays
end

function shopImpl.getGiftInfoList(roleId, data)
	-- if data then
	-- 	local roleCtrl = require("role.role_ctrl")
	-- 	roleCtrl.shopTest(roleId, data)
	-- end
	local response = {}
	response.giftInfoList = shopCtrl.getGiftInfoList(roleId) or {}
	return SystemError.success, response
end

return shopImpl