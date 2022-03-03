local inviteCtrl = {}

local context = require('common.context')
local dbHelp = require("common.db_help")
local configDb = require("config.config_db")
local inviteConf = configDb.invite_config
local inviteConst = require("invite.invite_const")
local awardStatus = inviteConst.awardStatus

local activityTimeCtrl = require("activity.activity_time_ctrl")
local activityConst = require("activity.activity_const")
local activityTimeConst = activityConst.activityTime
local roleCtrl = require("role.role_ctrl")
local roleConst = require("role.role_const")
local logConst = require("game.log_const")
local activityStatus = require("activity.activity_const").activityStatus
local resCtrl = require("common.res_operate")

function inviteCtrl.getInfo(roleId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.invite)
	if not flag then
		return ActivityError.notOpen
	end

	--畅玩有礼
	local playStatus = awardStatus.canGet
	local playInfo = dbHelp.call("invite.getPlayInfo", roleId)
	if playInfo then
		playStatus = awardStatus.hasGet
	end

	--邀请有礼
	local inviteStatus = {}
	local inviteInfo = dbHelp.call("invite.getInviteInfo", roleId)
	local imeiList = inviteInfo.imeiList or {}
	for _,v in pairs(inviteConf) do
		local status = awardStatus.canNotGet
		if #imeiList >= v.num then
			if inviteInfo[tostring(v.id)] then
				status = awardStatus.hasGet
			else
				status = awardStatus.canGet
			end
		end
		table.insert(inviteStatus, {id = v.id, status = status})
	end

	--充值有礼
	local info = dbHelp.call("invite.getChargeInfo", roleId)
	local chargeNum = info.chargeNum or 0
	local getAmount = info.getAmount or 0

	local canGetAmount = math.floor(chargeNum/100) * inviteConst.chargeAwardNum
	local leftAmount = canGetAmount - getAmount

	local result = {}
	result.playStatus = playStatus
	result.inviteStatusList = inviteStatus
	result.chargeAmount = leftAmount
	result.totalAmount = canGetAmount
	result.inviteNum = #imeiList
	-- print("result",tableToString(result))
	return SystemError.success, result

end

function inviteCtrl.getPlayAward(roleId, inviteId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.invite)
	if not flag then
		return ActivityError.notOpen
	end

	if roleId == inviteId then
		return InviteError.inviteIdNotExist
	end

	local activityInfo = activityTimeCtrl.getActivityTime(activityTimeConst.invite)

	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if roleInfo.createTime < activityInfo.sTime or roleInfo.createTime > activityInfo.eTime then
		return InviteError.notInActivityTime
	end

	local isExist = dbHelp.call("auth.checkRoleIsExist", inviteId)
	if not isExist then
		return InviteError.inviteIdNotExist
	end

	local info = dbHelp.call("invite.getPlayInfo", roleId)
	if info then
		return InviteError.hadGot
	end

	local chargeAddStatus     	--充值时邀请人是否有额外收益
	if roleInfo.mobileNum and roleInfo.imei then
		local inviteInfo = dbHelp.call("invite.getInviteInfo", inviteId)
		local imeiList = inviteInfo.imeiList or {}
		if not table.find(imeiList, roleInfo.imei) then
			table.insert(imeiList, roleInfo.imei)
			dbHelp.send("invite.addInviteNum", inviteId, imeiList)
			chargeAddStatus = true
			--发红点
			local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", inviteId)
			if agentAdress then
				for _,v in pairs(inviteConf) do
					if #imeiList >= v.num and not inviteInfo[tostring(v.id)] then
						context.sendS2C(inviteId, M_RedPoint.handleActive, {data = "Invite"})
						break
					end
				end
			end
		end
	end

	local data = {
		roleId = roleId,
		inviteId = inviteId,
		chargeAddStatus = chargeAddStatus,
	}

	dbHelp.send("invite.addPlayInfo", data)

	local award = inviteConst.playAward
	resCtrl.sendList(roleId, award, logConst.inviteGet)

	return SystemError.success
end

function inviteCtrl.getInviteAward(roleId, awardIndex)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.invite)
	if not flag then
		return ActivityError.notOpen
	end

	local info = dbHelp.call("invite.getInviteInfo", roleId)
	local imeiList = info.imeiList or {}

	if info[tostring(awardIndex)] then
		return ActivityError.canNotGet
	end

	local conf = inviteConf[awardIndex]
	local award = conf.award
	local num = conf.num
	if #imeiList < num then
		return InviteError.inviteNotEnough
	end

	dbHelp.call("invite.updateInviteInfo", roleId, awardIndex)

	resCtrl.sendList(roleId, {award}, logConst.inviteGet)

	return SystemError.success	
end

function inviteCtrl.getChargeAward(roleId)
	local flag = activityTimeCtrl.isActivityOpen(activityTimeConst.invite)
	if not flag then
		return ActivityError.notOpen
	end

	local info = dbHelp.call("invite.getChargeInfo", roleId)
	local chargeNum = info.chargeNum or 0
	local getAmount = info.getAmount or 0

	local canGetAmount = math.floor(chargeNum/100) * inviteConst.chargeAwardNum
	local leftAmount = canGetAmount - getAmount
	if leftAmount <= 0 then
		return InviteError.canNotGet
	end

	dbHelp.call("invite.updateChargeInfo", roleId, "getAmount", leftAmount)

	resCtrl.send(roleId, roleConst.GOLD_ID, leftAmount, logConst.inviteGet)

	return SystemError.success 
end

return inviteCtrl