local skynet  	= require("skynet")
local logger  	= require("log")
local context 	= require("common.context")
local redMoney    = require("service_base")
local dbHelp 	= require("common.db_help")
local logConst  = require("game.log_const")
local command = redMoney.command
local redMoneyConst = require("red_money.red_money_const")
local activityConf = require("config.activity_config")
local redMoneyActivityConf = activityConf[redMoneyConst.activityId]
local oneDaySec = 86400
local oneHourSec = 3600
local oneMinSec = 60

local startHour = redMoneyConst.startHour

local redMoneyTest = skynet.getenv("redMoneyTest")
local activityTimeConst = require("activity.activity_const").activityTime
local activityStatus = require("activity.activity_const").activityStatus

local sendFlag = false
local sendRoles = {}

local sendRoleRankInfos = {}

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

--------------------------------------------------------------------------------

function command.getRedMoney(roleId, nickname)
	if not sendFlag then
		return
	end
	if sendRoles[roleId] then
		return
	end
	if table.nums(sendRoles) >= redMoneyConst.joinNum then
		return 
	end
	local luckyNum = command.getRandomMoney()
	local goldNum = luckyNum * redMoneyConst.step

	local logInfo = {goldNum = goldNum, nickname = nickname, getTime = os.date("%X")}
	sendRoles[roleId] = logInfo
	table.insert(sendRoleRankInfos, 1, logInfo)

	return SystemError.success, goldNum
end

function command.getRandomMoney()
	local luckyNum = math.rand(1, 100)
	local numMap = redMoneyConst.numMap
	local startNum = 0
	local luckyIndex
	for i=1,#numMap do
		if luckyNum > startNum and luckyNum <= numMap[i].weight then
			luckyIndex = i
			break
		end
		startNum = numMap[i].weight
	end
	local chooseMap = numMap[luckyIndex]
	return math.rand(chooseMap.min, chooseMap.max)
end

function command.getSendRoles()
	return sendRoleRankInfos
end

function command.getActivityFlag()
	return sendFlag
end

---------------------------------每轮红包逻辑-----------------------------------

local function getStepSec()
	local stepSec = redMoneyConst.stepSec
	return math.rand(stepSec[1], stepSec[2])
end

local nextRollAt
local function doActivityLogic(isOpen)
	if isOpen ~= sendFlag then 
		if isOpen then 
			if not isActivtyOn() then
				return
			end
			sendFlag = isOpen
			sendRoles = {}
			sendRoleRankInfos = {} 
			context.castS2C(nil, M_RedMoney.handleStart)
		else 
			sendFlag = isOpen
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
		if table.nums(sendRoles) < redMoneyConst.joinNum then
			context.castS2C(nil, M_RedMoney.handleMoneySend, nil, nil, excludeMap)
		end
	end
end

local function updateActivity()
	skynet.timeout(100, function()
			updateActivity()
		end)
	
	local flag = false
	local curDate = os.date("*t")
	local wday = curDate.wday
	local passSec = curDate.hour * oneHourSec + curDate.min * oneMinSec + curDate.sec
	for _,periodInfo in pairs(redMoneyConst.ActivePeriodList) do
		if table.find(periodInfo.wdays, wday) then
			local startHour = periodInfo.startHour.hour * oneHourSec + periodInfo.startHour.min * oneMinSec + periodInfo.startHour.sec
			local endHour = periodInfo.endHour.hour * oneHourSec + periodInfo.endHour.min * oneMinSec + periodInfo.endHour.sec
			if startHour < passSec and passSec < endHour then 
				flag = true
				break
			end
		end 
	end
	doActivityLogic(flag)
end

-- 启动进程
function redMoney.onStart()
	skynet.register(SERVICE.RED_MONEY)
	print("red money server start")
	updateActivity()
end

redMoney.start()

