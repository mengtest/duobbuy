local scoreLotteryDb = {}
local context = require("common.context")

function scoreLotteryDb.getInfo(db, roleId, round)
	local ret = db.ScoreLottery:findOne({roleId = roleId, round = round})
	return ret or {}
end

function scoreLotteryDb.incrLotteryTimes(db, roleId, round, times)
	db.ScoreLottery:update(
		{ roleId = roleId, round = round },
		{ ["$inc"] = { lotteryTimes = times } },
		true
	)
end

function scoreLotteryDb.incrScore(db, roleId, round, score)
	db.ScoreLottery:update(
		{ roleId = roleId, round = round },
		{ ["$inc"] = { score = score } },
		true
	)
end

function scoreLotteryDb.updateScoreLotteryInfo(db, roleId, round, awardId)
	db.ScoreLottery:update(
		{ roleId = roleId, round = round },
		{ ["$set"] = { [tostring(awardId)] = true } },
		true
	)
end

function scoreLotteryDb.addRecord(db, roleId, info)
	local id = context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "ScoreLotteryRecord")
	local data = {
		_id = id,
		roleId = roleId,
		goodsType = info.goodsType,
		goodsName = info.goodsName,
		nickname = info.nickname,
		sTime = os.time(),
		prizeId = info.prizeId,
		status = info.status,
		round = info.round,
	}
	db.ScoreLotteryRecord:insert(data)
end

return scoreLotteryDb