local boxCtrl = require("box.box_ctrl")

local boxImpl = {}

function boxImpl.open(roleId, boxId)
	return boxCtrl.open(roleId, boxId)
end

function boxImpl.getInfo(roleId)
	local data, maxChargeNum, curChargeNum  = boxCtrl.getInfo(roleId)
	return SystemError.success, {data = data, maxChargeNum = maxChargeNum, curChargeNum = curChargeNum}
end

return boxImpl