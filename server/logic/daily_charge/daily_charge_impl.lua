local dailyChargeCtrl = require("daily_charge.daily_charge_ctrl")
local dailyChargeImpl = {}

function dailyChargeImpl.getInfo(roleId)
	return dailyChargeCtrl.getInfo(roleId)
end

function dailyChargeImpl.getDailyAward(roleId)
	return dailyChargeCtrl.getDailyAward(roleId)
end

function dailyChargeImpl.getContinueAward(roleId, day)
	return dailyChargeCtrl.getContinueAward(roleId, day)
end

return dailyChargeImpl