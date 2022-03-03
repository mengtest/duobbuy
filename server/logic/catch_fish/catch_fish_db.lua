local catchFishDb = {}

function catchFishDb.setAwardPool(db, value)
    return db.AwardPool:update(
        {["_id"] = 1},
        {["$set"] = {["value"] = value}},
        true
    )
end

function catchFishDb.getAwardPool(db)
	local data = db.AwardPool:findOne({_id = 1})
    if not data then
        return 0
    end
    return data.value
end

function catchFishDb.addArenaResult(db, data)
    local results = {}
    for _, item in pairs(data.items) do
        results[#results + 1] = {roleId = item.roleId
            , nickname = item.nickname
            , rank = item.rank
            , score = item.score
            , goodsId = item.goodsId
            , award = item.award
            , type = data.type
            , level = data.level
            , time = os.time()
        } 
    end
    db.ArenaResult:batch_insert(results)
end

function catchFishDb.getArenaResults(db, roleId)
    local cursor = db.ArenaResult:find({roleId = roleId}):sort({time=-1}):limit(10)
    local results = {}
    while cursor:hasNext() do
        local result = cursor:next()
        result._id = nil
        result.nickname = nil
        result.roleId = nil
        results[#results + 1] = result
    end

    return results
end

function catchFishDb.freezeBet(db, roleId, goodsId, amount)
    db.Bet:insert({_id = roleId, goodsId = goodsId, amount = amount})
end

function catchFishDb.unfreezeBet(db, roleId)
    local bet = db.Bet:findOne({_id = roleId})
    if bet then
        db.Bet:delete({_id = roleId}, true)
    end
    return bet
end

function catchFishDb.deleteBet(db, roleId)
    db.Bet:delete({_id = roleId}, true)
end

function catchFishDb.getBet(db, roleId)
    return db.Bet:findOne({_id = roleId})
end

function catchFishDb.addArenaIncome(db, info)
    info.time = os.time()
    db.ArenaIncome:insert(info)
end

function catchFishDb.getWinRate(db, roleId, level)
    local total = db.ArenaResult:find({roleId = roleId, type = 2, level = level},{roleId = 1}):count()
    if total == 0 then
        return 0.25
    end

    local win = db.ArenaResult:find({roleId = roleId, type = 2, level = level, rank = 1},{roleId = 1}):count()
    return win / total
end

return catchFishDb