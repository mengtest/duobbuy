local goldGunCtrl = require("gold_gun.gold_gun_ctrl")
local goldGunImpl = {}

function goldGunImpl.getInfo(roleId)
	return goldGunCtrl.getInfo(roleId)
end

function goldGunImpl.lottery(roleId, level)
	return goldGunCtrl.lottery(roleId, level)
end

function goldGunImpl.getGoodsRecords(roleId)
	local ec, records = goldGunCtrl.getGoodsRecords(roleId)
	if ec ~= SystemError.success then 
		return ec
	end
	return SystemError.success, {records = records}
end

return goldGunImpl