local skynet = require("skynet")
local roleCtrl = require("role.role_ctrl")
local dbHelp = require ("common.db_help")
local configDb = require("config.config_db")
local logConst = require("game.log_const")
local resCtrl = require("common.res_operate")
local context = require("common.context")
local loginAwardConfig = configDb.login_award_config
local sevenDayConst = require("seven_day.seven_day_const")
local AwardStatus = sevenDayConst.awardStatus
local ChargeStatus = sevenDayConst.chargeStatus
local sevenDayCtrl = {}
local loginCache = {}
local chargeMoneyCache = {}
local OneDaySec = 86400 -- 	一天的秒数

function sevenDayCtrl.getLoginInfo(roleId, requestDay)
	local loginInfo = loginCache[roleId]
	if not loginInfo then
		loginInfo = dbHelp.call("sevenDay.getLoginInfo", roleId)
		loginCache[roleId] = loginInfo
	end
	local existFlag = false
	if requestDay then
		for _, info in pairs(loginInfo) do
			if info.day == requestDay then
				existFlag = true
				break
			end
		end
		if not existFlag and #loginInfo < 7 then
			local curIndex = #loginInfo
			loginInfo[curIndex+1] = {
				day = requestDay,
				roleId = roleId,
				index = curIndex+1,
			}
		end
	end

	return loginInfo
end

function sevenDayCtrl.getChargeAmount(roleId, day)
	if not chargeMoneyCache[roleId] then
		chargeMoneyCache[roleId] = {}
	end
	local chargeMoney = chargeMoneyCache[roleId][day]
	local curDay = os.date("%Y%m%d")
	if curDay == day or not chargeMoney then
		local year = tonumber(string.sub(day, 0, 4))
		local month = tonumber(string.sub(day, 5, 6))
		local dayTwo = tonumber(string.sub(day, 7, 8))
		local dayStartSec = os.time({year = year, month = month, day = dayTwo, hour = 0, min = 0, sec = 0})
		local dayEndSec = dayStartSec + OneDaySec - 1
		chargeMoney = dbHelp.call("charge.getRoleChargeAmount", roleId, dayStartSec, dayEndSec)
		chargeMoneyCache[roleId][day] = chargeMoney
	end
	return chargeMoney
end

function sevenDayCtrl.getInfo(roleId)
	local sec = sec or os.time()
	local curDay = os.date("%Y%m%d", sec)
	local loginInfo = sevenDayCtrl.getLoginInfo(roleId, curDay)
	local list = {}
	local isExistFlag = false
	for _,info in pairs(loginInfo) do
		local index = info.index
		local day = info.day
		local chargeMoney = sevenDayCtrl.getChargeAmount(roleId, day)
		local loginAward, chargeAward
		if info.award then
			loginAward = AwardStatus.hadGet
		else
			loginAward = AwardStatus.canGet
		end
		if info.charge then
			chargeAward = ChargeStatus.hadGet
		else
			if loginAwardConfig[index] and chargeMoney >= loginAwardConfig[index].recharge then
				chargeAward = ChargeStatus.canGet
			else
				if curDay > day then
					chargeAward = ChargeStatus.timeOut
				else
					chargeAward = ChargeStatus.canNotGet
				end
			end			
		end
		list[index] = {
			index = index,
			loginAward = loginAward,
			chargeAward = chargeAward,
			chargeMoney = chargeMoney,
		}
		if curDay == day then
			isExistFlag = true
		end
	end
	local dayEndTime = roleCtrl.getDayEndTime(sec)
	local leftSec = dayEndTime - sec
	local result = {leftSec = leftSec, list = list}
	return result, loginInfo
end

function sevenDayCtrl.getLoginAward(roleId, index)
	local info, loginInfo = sevenDayCtrl.getInfo(roleId)
	local list = info.list
	if not list[index] then
		return SevenDayError.notOpen
	end
	local status = list[index].loginAward
	if status ~= AwardStatus.canGet then
		return SevenDayError.notOpen
	end
	local day = loginInfo[index].day
	dbHelp.send("sevenDay.updateAwardStatus", roleId, day)
	loginInfo[index].award = true

	local award = loginAwardConfig[index].loginAward
	if award.goodsId then
		resCtrl.send(roleId, award.goodsId, award.amount, logConst.sevenDayLoginGet)
	elseif award.gunId then
		resCtrl.addGun(roleId, award.gunId, logConst.sevenDayLoginGet, award.time)
	end
	return SystemError.success
end

function sevenDayCtrl.getChargeAward(roleId, index)
	local info, loginInfo = sevenDayCtrl.getInfo(roleId)
	local list = info.list
	if not list[index] then
		return SevenDayError.notOpen
	end
	local status = list[index].chargeAward
	if status ~= ChargeStatus.canGet then
		return SevenDayError.canNotGet
	end
	local day = loginInfo[index].day
	dbHelp.send("sevenDay.updateChargeStatus", roleId, day)
	loginInfo[index].charge = true

	local award = loginAwardConfig[index].rechargeAward
	if award.goodsId then
		resCtrl.send(roleId, award.goodsId, award.amount, logConst.sevenDayChargeGet)
	elseif award.gunId then
		resCtrl.addGun(roleId, award.gunId, logConst.sevenDayChargeGet, award.time)
	end
	return SystemError.success
end


function sevenDayCtrl.addLoginLog(roleId, sec)
	local loginInfo = sevenDayCtrl.getLoginInfo(roleId)
	if #loginInfo >= sevenDayConst.maxDay then
		return
	end
	local sec = sec or os.time()
	local date = os.date("%Y%m%d", sec)
	for _,info in pairs(loginInfo) do
		if info.day == date then
			sevenDayCtrl.handeDayChange(roleId, sec)
			return
		end
	end
	local index = #loginInfo+1
	loginInfo[index] = {
		roleId = roleId,
		day = date,
		index = index,
	}
	dbHelp.send("sevenDay.recordLogin", roleId, date, index)
	if #loginInfo < sevenDayConst.maxDay then
		sevenDayCtrl.handeDayChange(roleId, sec)
	end
end

function sevenDayCtrl.handeDayChange(roleId, sec)
	local sec = sec or os.time()
	local dayEndTime = roleCtrl.getDayEndTime(sec)
	skynet.timeout( (dayEndTime-sec)*100, function()
		sevenDayCtrl.addLoginLog(roleId)
	end )
end


function sevenDayCtrl.onLogin(roleId)
	sevenDayCtrl.addLoginLog(roleId)
end

return sevenDayCtrl