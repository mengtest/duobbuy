local resCtrl = require("common.res_operate")
local potConst = require("pot.pot_const")
local logConst = require("game.log_const")
local dbHelp = require("common.db_help")
local context = require("common.context")
local endTime = potConst.endTime
local startTime = potConst.startTime
local openTime = potConst.openTime
local potCtrl = {}

local CodeLength = potConst.codeLength	--  票长度
local OneDaySec = 86400 -- 	一天的秒数
local OneHourSec = 3600	--	一小时的秒数
local OneMinSec = 60 	--	一分钟的秒数

local cacheRecordInfo = {}
local cacheRoleRoundInfo = {}

local function getCurRound(sec)
	local sec = sec or os.time()
	local offsetSec = OneDaySec - OneHourSec * startTime.hour - OneMinSec * startTime.min - startTime.sec
	sec = sec + offsetSec
	return os.date("%Y%m%d", sec)
end

local function codeToString(num)
	if not num then
		return
	end
	return string.sub(tostring(num + 100000), 2)
end

local function judgeAwardPos(luckyNum, roleCode)
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

local function isCodeOk(code)
	local length = string.len(code)
	if length ~= CodeLength then
		return false
	end
	local list = {'0','1','2','3','4','5','6','7','8','9'}
	for i=1,CodeLength do
		local char = string.sub(code, i, i)
		if not table.find(list, char) then
			return false
		end
	end
	return true
end

function potCtrl.bet(roleId, code, num)
	if num <= 0 then
		return SystemError.argument
	end
	if not isCodeOk(code) then
		return PotError.codeError
	end
	local code = tonumber(code) or 0
	local curSec = os.time()
	local timeDate = os.date("*t", curSec)
	local endSec = endTime.hour * OneHourSec + endTime.min * OneMinSec + endTime.sec
	local startSec = startTime.hour * OneHourSec + startTime.min * OneMinSec + startTime.sec
	local judgeSec = timeDate.hour * OneHourSec + timeDate.min * OneMinSec + timeDate.sec
	if judgeSec >= endSec and judgeSec <= startSec then
		return PotError.timeError
	end
	local ec = resCtrl.costTreasure(roleId, num * potConst.costTreause, logConst.potCost)
	if ec ~= SystemError.success then
		return ec
	end
	local round = getCurRound(curSec)
	dbHelp.send("pot.addPotNumRecord", roleId, round, code, num)
	cacheRoleRoundInfo[roleId .. "-" .. round] = nil
	context.sendS2S(SERVICE.POT, "addGold", num * potConst.addGold)
	return SystemError.success
end

function potCtrl.getInfo(roleId)
	local goldNum = context.callS2S(SERVICE.POT, "getGoldNum")
	local curSec = os.time()
	local round = getCurRound(curSec)
	local records = potCtrl.getRoleHistory(roleId)
	local sysRecords = potCtrl.getSysHistory(roleId)
	local awardInfo = potCtrl.getPotAwardRecord(round)
	local luckyNum
	if #awardInfo >= 1 then
		luckyNum = awardInfo[1].luckyNum
	end

	local leftSec = 0
	local timeDate = os.date("*t", curSec)
	local openSec = openTime.hour * OneHourSec + openTime.min * OneMinSec + openTime.sec
	local startSec = startTime.hour * OneHourSec + startTime.min * OneMinSec + startTime.sec
	local judgeSec = timeDate.hour * OneHourSec + timeDate.min * OneMinSec + timeDate.sec
	if judgeSec >= openSec and judgeSec <= startSec then
		leftSec = startSec - judgeSec
	elseif judgeSec < openSec then
		leftSec = openSec - judgeSec
	elseif judgeSec > startSec then
		leftSec = startSec - judgeSec + OneDaySec
	end

	local result = {
		curRound = round,
		goldNum = goldNum,
		luckyNum = codeToString(luckyNum),
		isOpen = luckyNum and true or false,
		leftSec = leftSec,
		list = records,
		sysList = sysRecords,
	}
	return result
end

function potCtrl.getRoleHistory(roleId)
	local joinHistory = dbHelp.call("pot.getRoleJoinHistorys", roleId, 5)
	local result = {}
	for _,info in pairs(joinHistory) do
		local roundInfo = potCtrl.getPotAwardRecord(info.round)
		local luckyNum
		if #roundInfo >= 1 then
			luckyNum = roundInfo[1].luckyNum
		end
		result[#result+1] = {
			round = info.round,
			code = codeToString(luckyNum),
		}
	end

	return result
end

function potCtrl.getSysHistory(roleId)
	local rounds = dbHelp.call("pot.getLastAwardRound", 5)
	local result = {}
	for _,val in pairs(rounds) do
		result[#result+1] = {
			round = val.round,
			code = codeToString(val.luckyNum)
		}
	end
	return result
end

function potCtrl.getHistoryDetail(roleId, round)
	local awardInfo = potCtrl.getPotAwardRecord(round)
	local luckyNum
	if #awardInfo >= 1 then
		luckyNum = awardInfo[1].luckyNum
	end
	
	local result = {round = round, luckyNum = codeToString(luckyNum), list = {}}
	local joinHistory = potCtrl.getRoleRoundHistory(roleId, round)
	if not joinHistory then
		return result
	end
	local codes = joinHistory.codes or {}
	
	local data = {}
	for _,val in pairs(codes) do
		local code = val[1]
		local num = val[2]
		local goldNum = 0
		local pos
		if luckyNum then
			pos = judgeAwardPos(luckyNum, code)
			if pos then
				goldNum = awardInfo[pos].canGetPerNum
			end
		end
		data[#data+1] = {
			code = codeToString(code),
			num = num,
			goldNum = goldNum,
			pos = pos
		}
	end
	result.list = data
	return result
end

function potCtrl.getRoundDetail(round)
	local awardInfo = potCtrl.getPotAwardRecord(round)
	local luckyNum
	if #awardInfo >= 1 then
		luckyNum = awardInfo[1].luckyNum
	end
	local result = {round = round, luckyNum = codeToString(luckyNum), list = {}}
	local data = {}
	for pos, val in pairs(awardInfo) do
		data[#data+1] = {
			pos = pos,
			num = val.totalNum,
			goldNum = val.canGetPerNum
		}
	end
	result.list = data
	return result
end

function potCtrl.getPotAwardRecord(round)
	local result = cacheRecordInfo[round]
	if not result or table.empty(result) then
		result = dbHelp.call("pot.getPotAwardRecord", round)
		if result and not table.empty(result) then
			cacheRecordInfo[round] = result
		end
	end
	return result
end

function potCtrl.getRoleRoundHistory(roleId, round)
	local result = cacheRoleRoundInfo[roleId .. "-" .. round]
	if not result or table.empty(result) then
		result = dbHelp.call("pot.getRoleRoundHistory", roleId, round)
		if result and not table.empty(result) then
			cacheRoleRoundInfo[roleId .. "-" .. round] = result
		end
	end
	return result
end

return potCtrl