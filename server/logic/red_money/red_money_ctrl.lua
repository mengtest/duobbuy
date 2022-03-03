local context = require("common.context")
local roleCtrl = require("role.role_ctrl")
local roleConst = require("role.role_const")
local roleEvent = require("role.role_event")
local resOperate = require("common.res_operate")
local logConst  = require("game.log_const")
local redMoneyCtrl = {}

function redMoneyCtrl.openBag(roleId)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	local award = {goodsId = roleConst.GOLD_ID, amount = 0}
	local ec, goldNum = context.callS2S(SERVICE.RED_MONEY, "getRedMoney", roleId, roleInfo.nickname)
	if ec == SystemError.success then
		resOperate.send(roleId, roleConst.GOLD_ID, goldNum, logConst.redMoneyGet)
		award.amount = goldNum
	end
	local sendRoles = context.callS2S(SERVICE.RED_MONEY, "getSendRoles")
	local result = {
		awardInfo = award,
		rankInfo = sendRoles,
	}
	return SystemError.success, result
end

function redMoneyCtrl.getActivityStatus(roleId)
	local flag = context.callS2S(SERVICE.RED_MONEY, "getActivityFlag")
	if flag then
		return 1
	else
		return 0
	end
end

return redMoneyCtrl