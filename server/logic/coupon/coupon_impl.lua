local couponImpl = {}

local couponCtrl = require("coupon.coupon_ctrl")

function couponImpl.getInfo(roleId)
	local ec, info = couponCtrl.getInfo(roleId)
	if ec ~= SystemError.success then
		return ec
	end
	info.joinTimes = nil
	info.excludes = nil
	return ec, info
end

function couponImpl.getAward(roleId, index)
	return couponCtrl.getAward(roleId, index)
end

function couponImpl.openCard(roleId, pos)
	return couponCtrl.openCard(roleId, pos)
end

return couponImpl