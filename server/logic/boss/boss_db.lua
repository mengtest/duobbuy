local bossDb = {}

local AwardState = require("boss.boss_const").AwardState

function bossDb.updateBossInfo(db, bossAp, bossCost)
    db.BossInfo:update(
        {["_id"] = 1},
        {["$set"] = {["bossAp"] = bossAp, ["bossCost"] = bossCost}},
        true
    )
end

function bossDb.getBossInfo(db)
	local data = db.BossInfo:findOne({_id = 1})
    if not data then
        return {bossAp = 0, bossCost = 0}
    end
    return {bossAp = data.bossAp, bossCost = data.bossCost}
end

function bossDb.addKillInfo(db, data)
    data.time = os.time()
    data.state = AwardState.DEALING
    db.BossKillInfo:insert(data)
end

function bossDb.getMyKillInfos(db, roleId)
    local cursor = db.BossKillInfo:find({roleId = roleId}):sort({time=-1}):limit(10)
    local results = {}
    while cursor:hasNext() do
        local result = cursor:next()
        results[#results + 1] = {prizeId = result.prizeId, time = result.time, state = result.state}
    end

    return results
end 

function bossDb.getKillInfos(db)
    local cursor = db.BossKillInfo:find({roleId = roleId}):sort({time=-1}):limit(20)
    local results = {}
    while cursor:hasNext() do
        local result = cursor:next()
        results[#results + 1] = {nickname = result.nickname, prizeId = result.prizeId, time = result.time}
    end

    return results
end

return bossDb