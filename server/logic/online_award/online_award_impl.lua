local onlineAwardImpl = {}

local onlineAwardCtrl = require("online_award.online_award_ctrl")

function onlineAwardImpl.getInfo(roleId)
	return onlineAwardCtrl.getInfo(roleId)
end

function onlineAwardImpl.receiveAward(roleId, awardId)
	return onlineAwardCtrl.receiveAward(roleId, awardId)
end

return onlineAwardImpl