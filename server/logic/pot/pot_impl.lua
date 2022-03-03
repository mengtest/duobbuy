local potCtrl = require("pot.pot_ctrl")
local potImpl = {}

function potImpl.getInfo(roleId)
	local result = potCtrl.getInfo(roleId)
	return SystemError.success, result
end

function potImpl.bet(roleId, data)
	local code, num = data.code, data.num
	return potCtrl.bet(roleId, code, num)
end

function potImpl.getHistoryDetail(roleId, data)
	local result = potCtrl.getHistoryDetail(roleId, data.data)
	return SystemError.success, result
end

function potImpl.getRoundDetail(roleId, data)
	local result = potCtrl.getRoundDetail(data.data)
	return SystemError.success, result
end

return potImpl