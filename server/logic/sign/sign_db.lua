local signDb = {}


function signDb.getMiscCode(db, roleId)
	roleId = tonumber(roleId)
	local data = db.ExchangeMiscCode:findOne({ ["_id"] = roleId }) or {}
	return data.miscCode
end

function signDb.setMiscCode(db, roleId, miscCode)
	roleId = tonumber(roleId)
	db.ExchangeMiscCode:update(
		{["_id"] = roleId},
		{["$set"] = {["miscCode"] = miscCode}},
		{upsert = true}
	)
end


function signDb.getSignInfo(db, roleId)
	roleId = tonumber(roleId)
	local data = db.ExchangeSign:findOne({ ["_id"] = roleId }) or {}
	return data.signInfo
end

function signDb.setSignInfo(db, roleId, signInfo)
	roleId = tonumber(roleId)
	db.ExchangeSign:update(
		{["_id"] = roleId},
		{["$set"] = {["signInfo"] = signInfo}},
		{upsert = true}
	)
end





-- function signDb.recordDaySign(db, roleId, round, index, day)
-- 	local data = {
-- 		roleId = roleId,
-- 		round = round,
-- 		index = index,
-- 		day = day,
-- 	}
-- 	db.Sign:insert(data)
-- end

-- function signDb.getSignInfo(db, roleId, round)
-- 	local ret = db.Sign:find({roleId = roleId, round = round})
-- 	local result = {}

-- 	while ret:hasNext() do
-- 		local info = ret:next()
-- 		result[info.index] = true
-- 	end
-- 	return result
-- end

-- function signDb.recordWeekSign(db, roleId, round, index)
-- 	local data = {
-- 		roleId = roleId,
-- 		round = round,
-- 		index = index,
-- 	}
-- 	db.SignWeek:insert(data)
-- end

-- function signDb.getWeekSignInfo(db, roleId, round)
-- 	local ret = db.SignWeek:find({roleId = roleId, round = round})

-- 	local result = {}

-- 	while ret:hasNext() do
-- 		local info = ret:next()
-- 		result[info.index] = true
-- 	end
-- 	return result
-- end

return signDb