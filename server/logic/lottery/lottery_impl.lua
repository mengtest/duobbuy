local lotteryCtrl = require("lottery.lottery_ctrl")
local lotteryImpl = {}

function lotteryImpl.getInfo(roleId)
	return lotteryCtrl.getInfo(roleId)
end

function lotteryImpl.getGoodsRecords(roleId)
	local records = lotteryCtrl.getGoodsRecord(roleId)
	return SystemError.success, {records = records}
end

function lotteryImpl.lottery(roleId, num)
	return lotteryCtrl.lottery(roleId, num)
end

function lotteryImpl.getRank(roleId)
	return lotteryCtrl.getRankInfo(roleId)
end

return lotteryImpl