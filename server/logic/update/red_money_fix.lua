-- telnet 127.0.0.1 5056
-- inject :06000011 ./logic/update/red_money_fix.lua

local dbHelp = require("common.db_help")
local hotfix = require("common.hotfix")
local roleConst = require("role.role_const")
local context = require("common.context")
local logConst   = require("game.log_const")
local logger = require("log")
local skynet = require("skynet")
local chargeConst = require("charge.charge_const")
local shopBagRate = chargeConst.shopBagRate
local configUpdater = require("update.config_updater")

local chargeOpRecord = skynet.getenv("chargeOpRecord")

local command = _P.lua.command
dump(_P.lua)
local chargeCtrl = require("charge.charge_ctrl")

local codecache = require("skynet.codecache")
codecache.clear()

command.onStart()
-- local onStart = hotfix.getupvalue(command.onStart, "onStart")
-- onStart.updateActivity = function () 
-- 	print("local function updateActivity() new")
-- 	skynet.timeout(500, function()
-- 			updateActivity()
-- 		end)
-- end

local function getStepSec()
	local stepSec = redMoneyConst.stepSec
	return math.rand(stepSec[1], stepSec[2])
end

local function isActivtyOn()
	local timeConfig = context.callS2S(SERVICE.ACTIVITY, "getActiviyTime", activityTimeConst.redPocket)
	if timeConfig then
		if timeConfig.status ~= activityStatus.open then
			return false
		else
			local curSec = os.time()
			local flag = (curSec >= timeConfig.sTime and curSec <= timeConfig.eTime)
			if flag == false then
				return false
			end
			return true
		end
	else
		local curSec = os.time()
		local flag = (curSec >= redMoneyActivityConf.beginTime and curSec <= redMoneyActivityConf.endTime)
		if flag == false then
			return false
		end
		return true
	end	
end

local function recordSendLog(sendRoles)
	dbHelp.send("redMoney.recordLog", sendRoles)
end

local updateActivity = hotfix.getupvalue(command.getRedMoney, "updateActivity")

local nextRollAt
local sendFlag = hotfix.getupvalue(command.getRedMoney, "sendFlag")
local sendRoles = hotfix.getupvalue(command.getRedMoney, "sendRoles")
local sendRoleRankInfos = hotfix.getupvalue(command.getRedMoney, "sendRoleRankInfos")
local function doActivityLogic(isOpen)
	logger.Infof("function doActivityLogic(isOpen)")
	if isOpen ~= sendFlag then 
		sendFlag = isOpen
		if sendFlag then 
			if not isActivtyOn() then
				return
			end
			sendRoles = {}
			sendRoleRankInfos = {} 
			context.castS2C(nil, M_RedMoney.handleStart)
		else 
			recordSendLog(sendRoles)
			sendRoles = {}
			sendRoleRankInfos = {} 
			context.castS2C(nil, M_RedMoney.handleEnd)
			return
		end 
	end 

	if sendFlag then 
		if not nextRollAt then 
			nextRollAt =  skynet.time() + getStepSec()
		end
		if nextRollAt < skynet.time() and not table.empty(sendRoles) then 
			recordSendLog(sendRoles)
			sendRoles = {}
			sendRoleRankInfos = {} 
			nextRollAt =  skynet.time() + getStepSec()
		end 

		local excludeMap = {}
		for roleId,_ in pairs(sendRoles) do
			excludeMap[roleId] = true
		end
		print("table.nums(sendRoles):"..table.nums(sendRoles))
		if table.nums(sendRoles) < redMoneyConst.joinNum then
			context.castS2C(nil, M_RedMoney.handleMoneySend, nil, nil, excludeMap)
		end
	end
end

local function updateActivity()
	print("local function updateActivity() new")
	skynet.timeout(500, function()
			updateActivity()
		end)
end

print("------------------ok")