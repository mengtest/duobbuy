local scoreLotteryCtrl = require("score_lottery.score_lottery_ctrl")
local scoreLotteryImpl = {}

function scoreLotteryImpl.getInfo(roleId)
	return scoreLotteryCtrl.getInfo(roleId)
end

function scoreLotteryImpl.lottery(roleId, num)
	return scoreLotteryCtrl.lottery(roleId, num)
end

function scoreLotteryImpl.getAward(roleId, awardId)
	return scoreLotteryCtrl.getAward(roleId, awardId)
end

return scoreLotteryImpl