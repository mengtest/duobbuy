local chatCtrl = {}
local dbHelp   = require("common.db_help")
local context = require("common.context")

-- 聊天
function chatCtrl.speakToWorld(roleId, data)
	if context.catchFishSvc then
		data.sender = roleId
		context.sendS2S(context.catchFishSvc, "chat", data)
	end

	-- Test zj
	-- if data.msgId then
	-- 	local chargeCtrl = require("charge.charge_ctrl")
	-- 	local num = tonumber(data.msgId)  * 10
	-- 	chargeCtrl.recordActivity(roleId, num)
	-- 	chargeCtrl.setRoleStatus(roleId, num)
	-- end
	
	-- 首充奖励通过邮件发送
	-- local chargeConst = require("charge.charge_const")
	-- local logConst   = require("game.log_const")
	-- local language 	= require("language.language")
	-- local fistPayAwardAttach = {}
	-- for _,award in ipairs(chargeConst.fistPayAward or {}) do
	-- 	table.insert(fistPayAwardAttach, {goodsId = award.goodsId, amount = award.amount, gunId = award.gunId, time = award.time})
	-- end
	-- if not table.empty(fistPayAwardAttach) then
	-- 	context.sendS2S(SERVICE.MAIL, "sendMail", roleId, 
	-- 		{
	-- 			mailType = 1, 
	-- 			pageType = 1, 
	-- 			source = logConst.chargeSend, 
	-- 			attach = fistPayAwardAttach, 
	-- 			title = "首充奖励", 
	-- 			content = "恭喜您完成了首次充值，请领取以下奖励...",
	-- 		})
	-- end

	return SystemError.success
end

return chatCtrl