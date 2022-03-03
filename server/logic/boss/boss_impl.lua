local skynet = require("skynet")
local bossImpl = {}
local context = require("common.context")
local roleCtrl = require("role.role_ctrl")
local resOp = require("common.res_operate")
local dbHelp = require("common.db_help")

function bossImpl.getMyKillInfo(roleId)
	local items = dbHelp.call("boss.getMyKillInfos", roleId)
	return SystemError.success, {items = items}
end

function bossImpl.getKillInfo(roleId)
	local items = dbHelp.call("boss.getKillInfos")
	return SystemError.success, {items = items}
end	

return bossImpl