local redMoneyCtrl = require("red_money.red_money_ctrl")
local redMoneyImpl = {}

function redMoneyImpl.openBag(roleId)
	return redMoneyCtrl.openBag(roleId)
end

function redMoneyImpl.getActivityStatus(roleId)
	local result = redMoneyCtrl.getActivityStatus(roleId)
	return SystemError.success, result
end

return redMoneyImpl