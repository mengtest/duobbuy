local WishPoolCtrl = require("wish_pool.wish_pool_ctrl")
local WishPoolImpl = {}

--获取许愿池界面信息
function WishPoolImpl.getInfo(roleId)
	local ec, result = WishPoolCtrl.getInfo(roleId)
	if ec ~= SystemError.success then 
		return ec
	end
	return SystemError.success, result
end

--许愿池许愿
function WishPoolImpl.makeWish(roleId, num)
	local ec, awardInfo = WishPoolCtrl.makeWish(roleId, num)
	if ec ~= SystemError.success then 
		return ec
	end
	return SystemError.success, {data = awardInfo}
end

--获取我的奖品
function WishPoolImpl.getGoodsRecords(roleId)
	local ec, records = WishPoolCtrl.getGoodsRecords(roleId)
	if ec ~= SystemError.success then 
		return ec
	end
	return SystemError.success, {records = records}
end

return WishPoolImpl