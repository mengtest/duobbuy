local luckyBagCtrl = require("lucky_bag.lucky_bag_ctrl")
local luckyBagImpl = {}

function luckyBagImpl.getInfo(roleId)
	local result = luckyBagCtrl.getInfo(roleId)
	return SystemError.success, result
end

function luckyBagImpl.getGoodsRecords(roleId)
	local records = luckyBagCtrl.getGoodsRecord(roleId)
	return SystemError.success, {records = records}
end

function luckyBagImpl.open(roleId, num)
	local ec, awards = luckyBagCtrl.open(roleId, num)
	if ec ~= SystemError.success then
		return ec
	end
	return SystemError.success, {data = awards}
end

return luckyBagImpl