local moneyTreeDb = {}
local context = require("common.context")

function moneyTreeDb.initMoneyTreeInfo(db, info)
	for k,data in pairs(info) do
		db.MoneyTree:safe_insert(data)
	end
end

function moneyTreeDb.resetInfo(db, info)
	for k,data in pairs(info) do
		db.MoneyTree:update(
			{["awardId"] = data.awardId, ["round"] = data.round},
			{["$set"] = {["num"] = data.num}}
		)
	end
end

function moneyTreeDb.incrInfo(db, round, awardId, num)
	db.MoneyTree:update(
		{["awardId"] = awardId, ["round"] = round},
		{["$inc"] = {["num"] = num}}
	)
end

function moneyTreeDb.getInfo(db, round)
	local rets = db.MoneyTree:find({round = round})
	local results = {}
    while rets:hasNext() do
        local result = rets:next()
        results[#results+ 1] = result
    end
    return results
end

function moneyTreeDb.getRecord(db, roleId, round, goodsType, limit)
	local rets = db.MoneyTreeRecord:find({roleId = roleId, goodsType = goodsType, round = round}):sort({sTime=-1}):limit(limit)

	local results = {}
    while rets:hasNext() do
        local result = rets:next()
        results[#results + 1] = {
        	roleId = result.roleId,
        	goodsType = result.goodsType,
			showFlag = result.showFlag,
			goodsName = result.goodsName,
			nickname = result.nickname,
			time = result.sTime,
			status = result.status
        }
    end

    return results
end

function moneyTreeDb.addRecord(db, roleId, info)
	local id = context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "MoneyTreeRecord")
	local data = {
		_id = id,
		roleId = roleId,
		goodsType = info.goodsType,
		showFlag = info.showFlag,
		goodsName = info.goodsName,
		nickname = info.nickname,
		sTime = os.time(),
		prizeId = info.prizeId,
		status = info.status,
		round = info.round,
	}
	db.MoneyTreeRecord:insert(data)
end

return moneyTreeDb