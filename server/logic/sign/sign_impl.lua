local signCtrl = require("sign.sign_ctrl")
local signImpl = {}

function signImpl.getInfo(roleId)
	local result = signCtrl.getInfo(roleId)
	return SystemError.success, result or {miscCode = ""}
end

function signImpl.getDayAward(roleId, index)
	return signCtrl.getDayAward(roleId, index)
end

function signImpl.getWeekAward(roleId, index)
	return signCtrl.getWeekAward(roleId, index)
end

return signImpl