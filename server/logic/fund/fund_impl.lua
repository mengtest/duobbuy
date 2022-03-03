local context = require("common.context")
local fundCtrl = require("fund.fund_ctrl")
local fundImpl = {}

function fundImpl.join(roleId, data)
	local itemId, joinNum, round = data.itemId, data.joinNum, data.round
	return fundCtrl.join(roleId, itemId, round, joinNum)
end

function fundImpl.exchange(roleId, itemId)
	return fundCtrl.exchange(roleId, itemId)
end

function fundImpl.readFundRecord(roleId, type)
	context.sendS2S(SERVICE.STATISTIC, "readFundRecord", roleId, type)
	return SystemError.success
end

return fundImpl