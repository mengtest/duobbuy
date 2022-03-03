local skynet  	= require("skynet")
local logger  	= require("log")
local json 		= require("json")
local pot   	= require("service_base")
local dbHelp    = require("common.db_help")
local context 	= require("common.context")
local potConst 	= require("pot.pot_const")
local language 	= require("language.language")
local logConst  = require("game.log_const")
local roleConst = require("role.role_const")
local command   = pot.command

local PotOpenTime = potConst.openTime
local PotAwardTime = potConst.startTime
local CodeLength = potConst.codeLength	--  票长度
local potGold = 0

local OneDaySec = 86400 -- 	一天的秒数
local OneHourSec = 3600	--	一小时的秒数
local OneMinSec = 60 	--	一分钟的秒数

local WaitAwardSec = (PotAwardTime.hour - PotOpenTime.hour) * OneHourSec + (PotAwardTime.min - PotOpenTime.min) * OneMinSec + PotAwardTime.sec - PotOpenTime.sec


local goldAwardRate = {
	0.35, 0.20, 0.15, 0.1
}
local maxGoldPerNum = {
	30000000, 10000000, 2000000, 500000
}

local function initPotGold()
	local amount = dbHelp.call("pot.getPotGold")
	if not amount then
		amount = potConst.initGold
		dbHelp.send("pot.setPotGold", amount)
	end
	potGold = amount
end

local function getCurRound(sec)
	local sec = sec or os.time()
	-- local offsetSec = OneDaySec - OneHourSec * PotOpenTime.hour - OneMinSec * PotOpenTime.min - PotOpenTime.sec
	-- sec = sec + offsetSec
	return os.date("%Y%m%d", sec)
end

function command.judgeAwardPos(luckyNum, roleCode)
	if luckyNum == roleCode then
		return 1
	end
	for pos=2,CodeLength - 1 do
		local delNum = 10 ^ (CodeLength - pos + 1)
		if luckyNum % delNum == roleCode % delNum then
			return pos
		end
	end
end

function command.sendAward(round, luckyNum, awardRoleInfos)
	logger.Info("sendAward start round:" .. round)
	local sendGoldNum = 0
	local records = {luckyNum = luckyNum, data = {}}

	for pos=1,CodeLength - 1 do
		local info = awardRoleInfos[pos]
		local recordInfo
		if info then
			local canGetGold = math.floor(potGold * goldAwardRate[pos])
			local canGetPerNum = math.floor(canGetGold / info.totalNum)

			if canGetPerNum > maxGoldPerNum[pos] then
				canGetPerNum = maxGoldPerNum[pos]
			end
			local roleIds = {}
			for roleId, num in pairs(info.data) do
				local goldNum = canGetPerNum * num
				sendGoldNum = sendGoldNum + goldNum

				skynet.timeout(WaitAwardSec * 100, function()
					context.sendS2S(SERVICE.MAIL, "sendMail", roleId, {mailType = 1, pageType = 1, source = logConst.potGet, 
						attach = {{goodsId = roleConst.GOLD_ID, amount = goldNum}}, 
						title = language("彩票奖池"), 
						content = language("彩票中奖", round, language(tostring(pos)), goldNum)
					})
				end)

				roleIds[#roleIds+1] = roleId
			end
			recordInfo = {luckyNum = luckyNum, canGetPerNum = canGetPerNum, totalNum = info.totalNum, roleIds = roleIds}
		else
			recordInfo = {luckyNum = luckyNum, canGetPerNum = 0, totalNum = 0, roleIds = {}}
		end
		dbHelp.send("pot.addPotAwardRecord", round, pos, recordInfo)
	end
	command.addGold(-sendGoldNum)

	skynet.timeout(WaitAwardSec * 100, function()
		local sec = os.time() + OneDaySec
		context.castS2C(nil, M_Pot.handleSendAward, {goldNum = potGold, leftSec = OneDaySec - WaitAwardSec, round = getCurRound(sec)})
	end)

	logger.Info("sendAward end sendGoldNum:" .. sendGoldNum)
end

function command.openPot(round)
	skynet.timeout(OneDaySec * 100, function()
		command.openPot()
	end)
	local round = round or getCurRound()
	logger.Info("openPot start round:" .. round)
	local luckyNum = math.rand(10000, 10^CodeLength-1)
	local lastNum = luckyNum % 100
	local records = dbHelp.call("pot.getPotLuckyRecords", round, lastNum)
	local awardRoleInfos = {}
	for _,record in pairs(records) do
		local pos = command.judgeAwardPos(luckyNum, record.code)
		assert(pos, "judgeAwardPos or potdb.getPotLuckyRecords error")
	 	if not awardRoleInfos[pos] then
	 		awardRoleInfos[pos] = {data = {}, totalNum = 0}
	 	end
	 	local awardData = awardRoleInfos[pos].data
	 	local roleId = record.roleId
	 	awardData[roleId] = (awardData[roleId] or 0) + record.num
	 	awardRoleInfos[pos].totalNum = awardRoleInfos[pos].totalNum + record.num
	end
	context.castS2C(nil, M_Pot.handleCodeOpen, {luckyNum = string.sub(tostring(luckyNum + 100000), 2), leftSec = WaitAwardSec})
	logger.Info("openPot end luckyNum:" .. luckyNum)
	command.sendAward(round, luckyNum, awardRoleInfos)
end

local function initCircleFunc()
	local curSec = os.time()
	local timeDate = os.date("*t", curSec)
	local passSec = timeDate.hour * OneHourSec + timeDate.min * OneMinSec + timeDate.sec
	local openSec = PotOpenTime.hour * OneHourSec + PotOpenTime.min * OneMinSec + PotOpenTime.sec
	local leftSec = openSec - passSec
	if leftSec < 0 then
		leftSec = leftSec + OneDaySec
	end

	skynet.timeout(leftSec * 100, function()
		command.openPot()
	end)
end

function command.addGold(amount)
	dbHelp.send("pot.incrPotGold", amount)
	potGold = potGold + amount
	return SystemError.success
end

function command.getGoldNum()
	return potGold
end


function pot.onStart()
	skynet.register(SERVICE.POT)
	initPotGold()
	initCircleFunc()
	print("pot server start")
end

pot.start()