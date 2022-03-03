local rankCtrl = {}
local rankConst = require("rank.rank_const")
local RankType  = rankConst.rankType
local AwardStatus = rankConst.awardStatus
local context 	= require("common.context")
local dbHelp    = require("common.db_help")
local configDb = require("config.config_db")
local resOperate = require("common.res_operate")
local logConst = require("game.log_const")
local roleEvent = require("role.role_event")
local arenaRankAwardConf = configDb.arena_rank_award
local oneDaySec = 86400
local oneWeekSec = 604800

function rankCtrl.getArenaDayInfo(roleId)
	local rankInfo = context.callS2S(SERVICE.RANK, "getList", RankType.dayArena, 50)
	local configList = {}
	if #rankInfo > 0 then
		configList = dbHelp.call("rank.getRankConfigAll", RankType.dayArena)
	end
	local list = {}
	local lastPos = 0
	for _,v in pairs(rankInfo) do
		local awardName = '';
		if configList[v.pos] and configList[v.pos].awardName then
			awardName = configList[v.pos].awardName
		end
		list[#list+1] = {pos = v.pos, nickname = v.nickname, score = v.score, awardName = awardName}
		if roleId == v.roleId then
			lastPos = v.pos
		end
	end

	local result = {list = list, lastPos = lastPos}
	
	return result
end

function rankCtrl.getArenaWeekInfo(roleId)
	local rankInfo = context.callS2S(SERVICE.RANK, "getList", RankType.weekArena, 50)
	local configList = {}
	if #rankInfo > 0 then
		configList = dbHelp.call("rank.getRankConfigAll", RankType.weekArena)
	end
	local list = {}
	local lastPos = 0
	for _,v in pairs(rankInfo) do
		local awardName = '';
		if configList[v.pos] and configList[v.pos].awardName then
			awardName = configList[v.pos].awardName
		end
		list[#list+1] = {pos = v.pos, nickname = v.nickname, score = v.score, awardName = awardName}
		if roleId == v.roleId then
			lastPos = v.pos
		end
	end
	
	local result = {list = list, lastPos = lastPos}

	return result
end

-- function rankCtrl.hadGetRankAward(roleId, rankType, key)
-- 	return dbHelp.call("rank.getRankAwardInfo", roleId, rankType, key) and true or false
-- end

-- function rankCtrl.getArenaDayAward(roleId)
-- 	local key = os.date("%Y%m%d", os.time() - oneDaySec)
-- 	if rankCtrl.hadGetRankAward(roleId, RankType.dayArena, key) then
-- 		return RankError.hadGet
-- 	end
-- 	local lastPos = dbHelp.call("rank.getRolePos", roleId, RankType.dayArena, key)
-- 	if lastPos and lastPos <= #arenaRankAwardConf[RankType.dayArena] then
-- 		local award = arenaRankAwardConf[RankType.dayArena][lastPos]
-- 		dbHelp.call("rank.recordRankAward", roleId, RankType.dayArena, key)
-- 		resOperate.send(roleId, award.goodsId, award.amount, logConst.arenaDayRankGet)
-- 		return SystemError.success
-- 	else
-- 		return RankError.canNotGet
-- 	end
-- end

-- function rankCtrl.getArenaWeekAward(roleId)
-- 	local key = os.date("%Y%W", os.time() - oneWeekSec)
-- 	if rankCtrl.hadGetRankAward(roleId, RankType.weekArena, key) then
-- 		return RankError.hadGet
-- 	end
-- 	local lastPos = dbHelp.call("rank.getRolePos", roleId, RankType.weekArena, key)
-- 	if lastPos and lastPos <= #arenaRankAwardConf[RankType.weekArena] then
-- 		local award = arenaRankAwardConf[RankType.weekArena][lastPos]
-- 		dbHelp.call("rank.recordRankAward", roleId, RankType.weekArena, key)
-- 		resOperate.send(roleId, award.goodsId, award.amount, logConst.arenaWeekRankGet)
-- 		return SystemError.success
-- 	else
-- 		return RankError.canNotGet
-- 	end
-- end


function rankCtrl.getAwardInfo(roleId)
	local info = dbHelp.call("rank.getGoodsAwardInfo", roleId)
	local result = {list = {}}
	local list = {}
	for _,v in pairs(info) do
		list[#list+1] = {
			time = string.sub(v.sTime, 1, 10),
			rankType = v.rankType,
			awardName = v.awardName,
			status = v.status,
			pos = v.pos,
		}
	end
	result.list = list
	return result
end

-----------------------------------------------------------------------------

function rankCtrl.sendRedPoint(roleId)
	local dayKey = os.date("%Y%m%d", os.time() - oneDaySec)
	local lastDayPos = dbHelp.call("rank.getRolePos", roleId, RankType.dayArena, dayKey)
	if not rankCtrl.hadGetRankAward(roleId, RankType.dayArena, dayKey) then
		if lastDayPos and lastDayPos <= #arenaRankAwardConf[RankType.dayArena] then
			context.sendS2C(roleId, M_RedPoint.handleActive, {data = "TODO"})
		end
	end

	local weekKey = os.date("%Y%W", os.time() - oneWeekSec)
	local lastWeekPos = dbHelp.call("rank.getRolePos", roleId, RankType.weekArena, weekKey)
	if not rankCtrl.hadGetRankAward(roleId, RankType.weekArena, weekKey) then
		if lastWeekPos and lastWeekPos <= #arenaRankAwardConf[RankType.weekArena] then
			context.sendS2C(roleId, M_RedPoint.handleActive, {data = "TODO"})
		end
	end
end

---------------------------------------------------------------------------------

function rankCtrl.onLogin(roleId)
	roleEvent.registerLoadOverEvent(function()
		rankCtrl.sendRedPoint(roleId)
	end)
end

-----------------------------------------------------------------------------------

return rankCtrl