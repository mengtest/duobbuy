local mobileCtrl = require("mobile.mobile_ctrl")
local mobileImpl = {}

function mobileImpl.sendActiveCode(roleId, data)
	local mobile = data.mobile
	return mobileCtrl.sendActiveCode(roleId, mobile)
end

function mobileImpl.checkActiveCode(roleId, data)
	local codeNum = data.codeNum
	local password = data.password
	return mobileCtrl.checkActiveCode(roleId, codeNum, password)
end

return mobileImpl