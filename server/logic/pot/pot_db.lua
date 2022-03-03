local potDb = {}
local skynet  	= require("skynet")

function potDb.getPotGold(db)
	local ret = db.PotGold:findOne({_id = 1}, {gold = 1})
	return ret and ret.gold
end

function potDb.setPotGold(db, amount)
	db.PotGold:update(
		{_id = 1},
		{["$set"] = { gold = amount }},
		true
	)
end

function potDb.incrPotGold(db, amount)
	db.PotGold:update(
		{_id = 1},
		{["$inc"] = { gold = amount }},
		true
	)
end

function potDb.getPotLuckyRecords(db, round, lastNum)
	local rets = db.PotRecord:find({
		round = round,
		lastNum = lastNum,
	})

	local result = {}
	while rets:hasNext() do
		result[#result+1] = rets:next()
	end
	return result
end

function potDb.addPotNumRecord(db, roleId, round, code, num)
	local data = {
		roleId = roleId,
		round = round,
		code = code,
		lastNum = code%100,
		num = num,
		time = skynet.time(),
	}

	db.PotRecord:insert(data)
	potDb.addRoleJoinHistory(db, roleId, round, code, num)
end

function potDb.getRoleJoinHistorys(db, roleId, limit)
	local rets = db.PotRoleHistory:find({roleId = roleId}):sort({round = -1}):limit(limit)
	local result = {}
	while rets:hasNext() do
		result[#result+1] = rets:next()
	end
	return result
end

function potDb.getRoleRoundHistory(db, roleId, round)
	local ret = db.PotRoleHistory:findOne({roleId = roleId, round = round})
	return ret
end

function potDb.addRoleJoinHistory(db, roleId, round, code, num)
	local ret = db.PotRoleHistory:findOne({roleId = roleId, round = round}, {codes = 1})
	if ret and ret.codes then
		local codes = ret.codes
		local existFlag = false
		for _,info in pairs(codes) do
			if info[1] == code then
				info[2] = info[2] + num
				existFlag = true
				break
			end
		end
		if not existFlag then
			codes[#codes+1] = {code, num}
		end

		db.PotRoleHistory:update(
			{roleId = roleId, round = round},
			{["$set"] = {codes = codes}}
		)
	else
		local data = {
			roleId = roleId,
			round = round,
			codes = {{code, num}}
		}
		db.PotRoleHistory:insert(data)
	end
end

function potDb.addPotAwardRecord(db, round, pos, info)
	local data = {
		round = round,
		pos = pos,
		luckyNum = info.luckyNum,
		roleIds = info.roleIds,
		totalNum = info.totalNum,
		canGetPerNum = info.canGetPerNum
	}
	db.PotAward:insert(data)
end

function potDb.getPotAwardRecord(db, round)
	local rets = db.PotAward:find({round = round})
	local result = {}
	while rets:hasNext() do
		local ret = rets:next()
		result[ret.pos] = ret
	end
	return result
end

function potDb.getLastAwardRound(db, limit)
	local rets = db.PotAward:find({pos = 1}, {round = 1, luckyNum = 1}):sort({round = -1}):limit(limit)
	local result = {}
	while rets:hasNext() do
		local ret = rets:next()
		result[#result+1] = {round = ret.round, luckyNum = ret.luckyNum}
	end
	return result
end

return potDb