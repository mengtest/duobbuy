local blessCtrl = require("bless.bless_ctrl")
local blessImpl = {}

function blessImpl.getInfo(roleId)
	return blessCtrl.getInfo(roleId)
end

function blessImpl.bless(roleId, blessId)
	return blessCtrl.bless(roleId, blessId)
end

function blessImpl.getAward(roleId, blessId)
	return blessCtrl.getAward(roleId, blessId)
end

function blessImpl.getGoodsRecords(roleId)
	local ec, records = blessCtrl.getGoodsRecords(roleId)
	return ec, {records = records}
end

return blessImpl