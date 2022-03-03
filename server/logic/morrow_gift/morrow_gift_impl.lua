local skynet  = require("skynet")
local morrowGiftCtrl = require("morrow_gift.morrow_gift_ctrl")
local morrowGiftImpl = {}

function morrowGiftImpl.getInfo(roleId)
	return morrowGiftCtrl.getClientInfo(roleId)
end

function morrowGiftImpl.getAward(roleId)
	return morrowGiftCtrl.getAward(roleId)
end

return morrowGiftImpl