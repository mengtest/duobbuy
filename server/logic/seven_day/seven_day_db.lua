local sevenDayDb = {}

function sevenDayDb.recordLogin(db, roleId, day, index)
	db.SevenDay:update(
		{roleId = roleId, day = day},
		{ ["$set"] = { index = index } },
		true
	)
end

function sevenDayDb.updateAwardStatus(db, roleId, day)
	db.SevenDay:update(
		{roleId = roleId, day = day},
		{ ["$set"] = { award = true } },
		false,
		true
	)
end

function sevenDayDb.updateChargeStatus(db, roleId, day)
	db.SevenDay:update(
		{roleId = roleId, day = day},
		{ ["$set"] = { charge = true } },
		false,
		true
	)
end

function sevenDayDb.getLoginInfo(db, roleId)
	local ret = db.SevenDay:find({roleId = roleId})
	local result = {}

	while ret:hasNext() do
		local info = ret:next()
		if not result[info.index] then
			result[info.index] = info
		end
	end
	return result
end

return sevenDayDb