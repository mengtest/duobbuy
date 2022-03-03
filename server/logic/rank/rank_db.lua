local rankDb = {}
local SendStatus = require("rank.rank_const").sendStatus

local context = require("common.context")
function rankDb.getIncrOrderId()
	return context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "RankGoodsAward")
end

function rankDb.recordRankToDb(db, rankType, key, info)
	db.RankData:update(
		{ rankType = rankType, key = key },
		{ ["$set"] = {info = info} },
		true
	)
end

function rankDb.recordPosToDb(db, rankType, key, info)
	db.RankPos:update(
		{ rankType = rankType, key = key },
		{ ["$set"] = {info = info} },
		true
	)
end

function rankDb.getRankFromDb(db, rankType, key)
	local ret = db.RankData:findOne({ rankType = rankType, key = key }, { info = 1})
	return ret and ret.info
end

function rankDb.getPosFromDb(db, rankType, key)
	local ret = db.RankPos:findOne({ rankType = rankType, key = key }, { info = 1})
	return ret and ret.info
end

function rankDb.getRolePos(db, roleId, rankType, key)
	local ret = db.RankPos:findOne({ rankType = rankType, key = key }, { info = 1})
	if ret and ret.info then
		return ret.info[tostring(roleId)]
	end
end

function rankDb.getTopRank(db, rankType, key, limit)
	local ret = db.RankData:findOne({ rankType = rankType, key = key }, { info = 1})
	if limit then
		if ret and ret.info then
			local result = {}
			for i=1,limit do
				if ret.info[i] then
					result[i] = ret.info[i]
				else
					break
				end
			end
			return result
		end
	end
	return ret and ret.info
end

----------------------------------------------------------------------------

function rankDb.getRankAwardInfo(db, roleId, rankType, key)
	local ret = db.RankAward:findOne( { rankType = rankType, roleId = roleId, key = key} )
	return ret and ret._id
end

function rankDb.recordRankAward(db, roleId, rankType, key)
	local data = {
		roleId = roleId,
		rankType = rankType,
		key = key,
	}
	db.RankAward:safe_insert(data)
end

--------------------------------------------------------------------------------

function rankDb.recordGoodsAward(db, roleId, rankType, awardName, pos, status, goodsId)
	local id = rankDb.getIncrOrderId()
	local data = {
		_id = id,
		roleId = roleId,
		rankType = rankType,
		awardName = awardName,
		sTime = os.date("%Y-%m-%d %H:%M:%S"),
		status = status,
		pos = pos,
		goodsId = goodsId,
	}
	db.RankGoodsAward:insert(data)
end

function rankDb.getGoodsAwardInfo(db, roleId)
	local ret = db.RankGoodsAward:find({roleId = roleId})
	local result = {}
	while ret:hasNext() do
		result[#result+1] = ret:next()
	end
	return result
end

----------------------------------------------------

function rankDb.getRankConfig(db, rankType, pos)
	local ret = db.ArenaRankConf:findOne({rankType = rankType, pos = pos})
	if ret then
		local result = {awardType = ret.awardType, goodsId = ret.goodsId, amount = ret.amount or 1, awardName = ret.awardName}
		return result
	end
end

function rankDb.getRankConfigAll(db, rankType)
	local ret = db.ArenaRankConf:find({rankType = rankType})
	local result = {}
	while ret:hasNext() do
		local info =  ret:next()
		result[info.pos] = {awardType = info.awardType, goodsId = info.goodsId, amount = info.amount or 1, awardName = info.awardName}
	end
	return result
end

return rankDb