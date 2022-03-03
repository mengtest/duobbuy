local lotteryDb = {}
local context = require("common.context")

function lotteryDb.getIncBagId(db)
	return context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "Lottery")
end

function lotteryDb.getRecord(db, roleId, round, goodsType, showFlag, limit)
	local rets = db.Lottery:find({roleId = roleId, round = round, goodsType = goodsType, showFlag = showFlag}):sort({sTime=-1}):limit(limit)

	local results = {}
    while rets:hasNext() do
        local result = rets:next()
        results[#results + 1] = {
        	roleId = result.roleId,
        	goodsType = result.goodsType,
			goodsName = result.goodsName,
			nickname = result.nickname,
			time = result.sTime,
			status = result.status
        }
    end

    return results
end

function lotteryDb.addRecord(db, roleId, round, info)
	local data = {
		_id = lotteryDb.getIncBagId(db),
		roleId = roleId,
		round = round,
		showFlag = info.showFlag,
		goodsType = info.goodsType,
		goodsName = info.goodsName,
		nickname = info.nickname,
		sTime = os.time(),
		prizeId = info.prizeId,
		status = info.status
	}
	db.Lottery:insert(data)
end

function lotteryDb.updateScore(db, roleId, round, addJoinTimes, addScore)
	local info = db.LotteryScore:findOne({roleId = roleId, round = round}) or {}
	local joinTimes = info.joinTimes or 0
	joinTimes = joinTimes + addJoinTimes
	local score = info and info.score or 0
	score = score + addScore
	db.LotteryScore:update(
			{roleId = roleId, round = round},
			{ ["$set"] = { ["joinTimes"] = joinTimes, ["score"] = score } },
			true
		)

	return {joinTimes = joinTimes, score = score}
end

function lotteryDb.updateRankInfo(db, round, rankInfo)
	db.LotteryRank:update(
		{round = round},
		{ ["$set"] = rankInfo },
		true
	)
end

function lotteryDb.getRankInfo(db, round)
	local rankInfo = db.LotteryRank:findOne({round = round})
	return rankInfo
end

return lotteryDb