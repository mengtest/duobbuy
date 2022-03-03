local sevenDayCtrl = require("seven_day.seven_day_ctrl")
local sevenDayImpl = {}

function sevenDayImpl.getInfo(roleId)
	local result = sevenDayCtrl.getInfo(roleId)
	return SystemError.success, result
end

function sevenDayImpl.getLoginAward(roleId, index)
	return sevenDayCtrl.getLoginAward(roleId, index)
end

function sevenDayImpl.getChargeAward(roleId, index)
	return sevenDayCtrl.getChargeAward(roleId, index)
end

return sevenDayImpl