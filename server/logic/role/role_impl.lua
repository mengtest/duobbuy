local roleCtrl = require("role.role_ctrl")
local roleConst = require("role.role_const")

local roleImpl = {}

function roleImpl.getRoleInfo(roleId)
	local ec, result = roleCtrl.getRoleInfoByView(roleId)
	return ec, result
end

function roleImpl.getFreeGold(roleId)
	local ec, freeGold = roleCtrl.getFreeGold(roleId)
	if ec ~= SystemError.success then
		return ec
	end
	local ecSec, leftSec = roleCtrl.getFreeGoldInfo(roleId)
	if ecSec ~= SystemError.success then
		leftSec = -1
	end
	local info = {
		goldNum = freeGold,
		leftTime = leftSec,
	}
	return SystemError.success, info
end

function roleImpl.getFreeGoldLeftSec(roleId)
	local ec, leftSec = roleCtrl.getFreeGoldInfo(roleId)
	if ec ~= SystemError.success then
		leftSec = -1
	end
	return SystemError.success, leftSec
end

function roleImpl.changeRoleInfo(roleId, data)
	return roleCtrl.changeRoleInfo(roleId, data)
end

function roleImpl.saveSeting(roleId, data)
	return roleCtrl.saveSeting(roleId, data)
end

function roleImpl.getSeting(roleId)
	local data = roleCtrl.getSeting(roleId)
	local result = {data = data}
	return SystemError.success, result
end

function roleImpl.shopTest(roleId, data)
	-- return roleCtrl.shopTest(roleId, data)
	return SystemError.success
end

function roleImpl.getFirstChargeInfo(roleId)
	local result = roleCtrl.getFirstChargeInfo(roleId)
	return SystemError.success, result
end

function roleImpl.loadOver(roleId)
	roleCtrl.loadOver(roleId)
	return SystemError.success
end

function roleImpl.getFundJoinsStatus(roleId)
	local data = roleCtrl.getFundJoinsStatus(roleId)
	local result = {data = data}
	return SystemError.success, result
end

function roleImpl.useGoldEnergy(roleId)
	return roleCtrl.useGoldEnergy(roleId)
end

function roleImpl.getChangeBagStatus(roleId, version)
	local data = roleCtrl.getChangeBagStatus(roleId, version)
	local result = {data = data}
	return SystemError.success, result
end

function roleImpl.getChangeBagAward(roleId, version)
	return roleCtrl.getChangeBagAward(roleId, version)
end

function roleImpl.getReturnStatus(roleId)
	local result = roleCtrl.getReturnStatus(roleId)
	return SystemError.success, result
end

function roleImpl.getReturnAward(roleId)
	return roleCtrl.getReturnAward(roleId)
end

function roleImpl.getWeChatFollowStatus(roleId)
	return roleCtrl.getWeChatFollowStatus(roleId)
end

function roleImpl.setWeChatFollowStatus(roleId)
	return roleCtrl.setWeChatFollowStatus(roleId)
end

return roleImpl