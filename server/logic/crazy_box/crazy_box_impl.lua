local crazyBoxCtrl = require("crazy_box.crazy_box_ctrl")
local crazyBoxImpl = {}

function crazyBoxImpl.getInfo(roleId)
	return crazyBoxCtrl.getInfo(roleId)
end

function crazyBoxImpl.openBox(roleId, positionId)
	return crazyBoxCtrl.openBox(roleId, positionId)
end

function crazyBoxImpl.getGoodsRecords(roleId)
	local ec, records = crazyBoxCtrl.getGoodsRecords(roleId)
	return ec, {records = records}
end

return crazyBoxImpl