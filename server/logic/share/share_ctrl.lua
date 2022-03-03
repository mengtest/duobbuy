local shareConst = require("share.share_const")
local configDb = require("config.config_db")
local dbHelp   = require("common.db_help")
local activityTotalConfig = configDb.activity
local activityConf = activityTotalConfig[shareConst.activityId]
local shareAward = activityConf.params.award
local roleCtrl = require("role.role_ctrl")
local resOperate = require("common.res_operate")
local logConst = require("game.log_const")

local shareCtrl = {}

function shareCtrl.shareSuccess(roleId)
	local flag = shareCtrl.canSendAward(roleId)
	if not flag then
		return SystemError.success, {goodsId = 0, amount = 0}
	end
	local ec = resOperate.send(roleId, shareAward.goodsId, shareAward.amount, logConst.dailyDiskFree)
	if ec ~= SystemError.success then
		return SystemError.success, {goodsId = 0, amount = 0}
	end
	local dayEndTime = roleCtrl.getDayEndTime()
	dbHelp.call("share.setRecord", roleId, dayEndTime)
	return ec, shareAward
end

-- 获取是否发奖励
function shareCtrl.canSendAward(roleId)
	local record = dbHelp.call("share.getRecord", roleId)
	if not record then
		return true
	else
		local sec = os.time()
		return record.endTime < sec
	end
end

return shareCtrl