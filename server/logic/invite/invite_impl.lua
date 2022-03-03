local inviteCtrl = require("invite.invite_ctrl")
local inviteImpl = {}

function inviteImpl.getInfo(roleId)
	return inviteCtrl.getInfo(roleId)
end

function inviteImpl.getPlayAward(roleId, inviteId)
	return inviteCtrl.getPlayAward(roleId, inviteId)
end

function inviteImpl.getInviteAward(roleId, awardIndex)
	return inviteCtrl.getInviteAward(roleId, awardIndex)
end

function inviteImpl.getChargeAward(roleId)
	return inviteCtrl.getChargeAward(roleId)
end

return inviteImpl