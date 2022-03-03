local skynet  	= require("skynet")
local logger  	= require("log")
local json 		= require("json")
local md5    	= require("md5")
local context 	= require("common.context")
local dbHelp    = require("common.db_help")
local rank   	= require("service_base")
local rankConst = require("rank.rank_const")
local RankType  = rankConst.rankType

local command 	= rank.command

local DbRecordSec = 300 -- 同步时间
local OneDaySec = 86400 -- 	一天的秒数
local OneHourSec = 3600	--	一小时的秒数
local OneMinSec = 60 	--	一分钟的秒数
local OneWeekSec = 604800

-----------------------------------------

local GloRankList = {}
local GloPosList = {}

----------------------------------------------------

local function getDayEndTime(sec)
	sec = sec or os.time()
	local timeDate = os.date("*t", sec)
	local dayEndTime = sec + OneDaySec - (timeDate.hour * OneHourSec + timeDate.min * OneMinSec + timeDate.sec)
	return dayEndTime
end

-------------------区分榜单逻辑-----------------------


local function initArenaDay()
	local key = os.date("%Y%m%d")
	return key
end

local function initArenaWeek()
	local key = os.date("%Y%W")
	return key
end

local initFuncList = {
	[ RankType.dayArena ] = initArenaDay,
	[ RankType.weekArena ] = initArenaWeek,
}

local function getRankList(rankType)
	if not GloRankList[rankType] then
		GloRankList[rankType] = {}
	end
	if initFuncList[rankType] then
		local initKey = initFuncList[rankType]()
		if not GloRankList[rankType][initKey] then
			GloRankList[rankType][initKey] = {}
		end
		return GloRankList[rankType][initKey], initKey
	else
		return GloRankList[rankType]
	end
end

local function getPosList(rankType)
	if not GloPosList[rankType] then
		GloPosList[rankType] = {}
	end
	if initFuncList[rankType] then
		local initKey = initFuncList[rankType]()
		if not GloPosList[rankType][initKey] then
			GloPosList[rankType][initKey] = {}
		end
		return GloPosList[rankType][initKey], initKey
	else
		return GloPosList[rankType]
	end
end

local function setRankList(rankType, info)
	if not GloRankList[rankType] then
		GloRankList[rankType] = {}
	end
	if initFuncList[rankType] then
		local initKey = initFuncList[rankType]()
		GloRankList[rankType][initKey] = info
	else
		GloRankList[rankType] = info
	end
end

local function setPosList(rankType, info)
	if not GloPosList[rankType] then
		GloPosList[rankType] = {}
	end
	if initFuncList[rankType] then
		local initKey = initFuncList[rankType]()
		GloPosList[rankType][initKey] = info
	else
		GloPosList[rankType] = info
	end
end

-------------------排序逻辑------------------------

local function sortRankWithPos(rankList, posList)
	table.sort(rankList, function(a, b)
		if a.score == b.score then
			if a.updateTime == b.updateTime then
				return a.roleId > b.roleId
			else
				return a.updateTime < b.updateTime
			end
		else
			return a.score > b.score
		end
	end)

	for index,rankInfo in pairs(rankList) do
		posList[rankInfo.roleId] = index
		rankInfo.pos = index
	end
end

--------------------入库出库逻辑------------------------

local function recordCacheToDb()
	for _,rankType in pairs(RankType) do
		local rankList, rankKey = getRankList(rankType)
		dbHelp.send("rank.recordRankToDb", rankType, rankKey, rankList)
		local posList, posKey = getPosList(rankType)
		dbHelp.send("rank.recordPosToDb", rankType, posKey, posList)
	end
	
	skynet.timeout(DbRecordSec * 100, function()
		recordCacheToDb()
	end)
end


local function getCacheFromDb()
	for _,rankType in pairs(RankType) do
		local rankList, rankKey = getRankList(rankType)
		rankList = dbHelp.call("rank.getRankFromDb", rankType, rankKey)
		if rankList then
			setRankList(rankType, rankList)
		end
		local posList, posKey = getPosList(rankType)
		posList = dbHelp.call("rank.getPosFromDb", rankType, posKey)
		if posList then
			local initPostList = {}
			for k,v in pairs(posList) do
				initPostList[tonumber(k)] = v
			end
			setPosList(rankType, initPostList)
		end
	end
end

local function clearCachle()
	for _,rankType in pairs(RankType) do
		local _, rankKey = getRankList(rankType)
		if rankKey then
			if GloRankList[rankType] then
				for key,v in pairs(GloRankList[rankType]) do
					if key ~= rankKey then
						GloRankList[rankType][key] = nil
					end
				end
			end
		end

		local _, posKey = getPosList(rankType)
		if posKey then
			if GloPosList[rankType] then
				for key,v in pairs(GloPosList[rankType]) do
					if key ~= posKey then
						GloPosList[rankType][key] = nil
					end
				end
			end
		end
	end

	skynet.timeout(OneDaySec * 100, function()
		clearCachle()
	end)
end

local function initRankService()
	getCacheFromDb()

	skynet.timeout(DbRecordSec * 100, function()
	 	recordCacheToDb()
	end)

	local curSec = os.time()
	local dayEndTime = getDayEndTime(curSec)
	skynet.timeout( (dayEndTime - curSec) * 100, function()
		clearCachle()
	end)
end

----------------------接口-----------------------

function command.addScore(rankType, roleId, score, nickname)
	local rankList = getRankList(rankType)
	local posList = getPosList(rankType)
	if posList[roleId] then
		local pos = posList[roleId]
		local rankInfo = rankList[pos]
		if score ~= 0 then
			rankInfo.score = (rankInfo.score or 0) + score
			rankInfo.updateTime = skynet.time()
		end
	else
		rankList[#rankList+1] = {roleId = roleId, score = score, nickname = nickname, updateTime = skynet.time()}
	end

	sortRankWithPos(rankList, posList)
end

function command.addArenaScore(roleId, score, nickname)
	command.addScore(RankType.dayArena, roleId, score, nickname)
	command.addScore(RankType.weekArena, roleId, score, nickname)
end

function command.getList(rankType, num)
	local rankList = getRankList(rankType)
	if num and num > 0 then
		local list = {}
		for i=1,num do
			if rankList[i] then
				list[i] = rankList[i]
			else
				break
			end
		end
		return list
	end
	return rankList
end

function command.getPos(roleId)
	local posList = getPosList(rankType)
	return posList[roleId]
end

function command.changeName(roleId, nickname)
	for _,rankType in pairs(RankType) do
		local rankList = getRankList(rankType)
		local posList = getPosList(rankType)
		if posList[roleId] then
			local pos = posList[roleId]
			local rankInfo = rankList[pos]
			rankInfo.nickname = nickname
		end
	end
end

function command.recordCacheToDb()
	recordCacheToDb()
end

function command.changeRecordSec(sec)
	local sec = tonumber(sec)
	if not sec or sec <= 0 then
		return
	end
	DbRecordSec = sec
end

-- 启动进程
function rank.onStart()
	skynet.register(SERVICE.RANK)
	initRankService()

	-- skynet.timeout(500, function()
	-- 	local startSec = skynet.time()
	-- 	local i = 1
	-- 	local total = 5000
	-- 	while i < total do
	-- 		local aSec 
	-- 		if i > total - 10 then
	-- 			aSec = skynet.time()
	-- 		end
	-- 			local score = math.rand(200, 100000)
	-- 			local roleId = math.rand(100, 100000)
	-- 			local nickname = 'test' .. roleId
				
	-- 			command.addScore(RankType.dayArena, roleId, score, nickname)

	-- 		if i > total - 10 then
	-- 			local bSec = skynet.time()
	-- 			print("step cost sec ", bSec - aSec, " index: ", i)
	-- 		end
				
	-- 		i = i + 1
	-- 	end
	-- 	local endSec = skynet.time()
	-- 	-- dump(GloRankList)
	-- 	-- dump(GloPosList)
	-- 	print("-------------------------------")
	-- 	print("total cost sec", endSec - startSec)

	-- end)
	print("rank server start")
end

rank.start()