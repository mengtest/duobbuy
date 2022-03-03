local relicCtrl = require("relic.relic_ctrl")
local relicImpl = {}

function relicImpl.getInfo(roleId)
	return relicCtrl.getInfo(roleId)
end

function relicImpl.lottery(roleId)
	return relicCtrl.lottery(roleId)
end

function relicImpl.getGoodsRecords(roleId)
	local ec, records = relicCtrl.getGoodsRecords(roleId)
	if ec ~= SystemError.success then 
		return ec
	end
	return SystemError.success, {records = records}
end

return relicImpl