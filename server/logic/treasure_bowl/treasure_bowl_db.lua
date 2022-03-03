local treasureBowlDb = {}

function treasureBowlDb.getInfo(db, roleId, round)
	local info = db.TreasureBowl:findOne({roleId = roleId, round = round})
	return info or {}
end

function treasureBowlDb.incrChargeMoney(db, roleId, round, amount)
	db.TreasureBowl:update(
		{ roleId = roleId, round = round },
		{ ["$inc"] = { ["chargeMoney"] = amount } },
		true
	)
end

function treasureBowlDb.updateInfo(db, roleId, round, joinTimes, leftGold)
	db.TreasureBowl:update(
		{ roleId = roleId, round = round },
		{ ["$set"] = { ["joinTimes"] = joinTimes, ["leftGold"] = leftGold} },
		true
	)
end

return treasureBowlDb