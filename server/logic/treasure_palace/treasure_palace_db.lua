local treasurePalaceDb = {}
local context = require("common.context")

function treasurePalaceDb.getInfo(db, roleId)
	local ret = db.TreasurePalace:findOne({_id = roleId})
	return ret or {}
end

function treasurePalaceDb.incrOpenTimes(db, roleId, times)
	db.TreasurePalace:update(
		{ _id = roleId},
		{["$inc"] = {["openTimes"] = times}},
		true
	)
end

function treasurePalaceDb.updatePosition(db, roleId, id)
	db.TreasurePalace:update(
		{ _id = roleId},
		{["$set"] = {["position"] = id}},
		true
	)
end

function treasurePalaceDb.getRecord(db, roleId, goodsType, limit)
	local rets = db.TreasurePalaceRecord:find({roleId = roleId, goodsType = goodsType}):sort({sTime=-1}):limit(limit)

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

function treasurePalaceDb.addRecord(db, roleId, info)
	local id = context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "TreasurePalaceRecord")
	local data = {
		_id = id,
		roleId = roleId,
		goodsType = info.goodsType,
		goodsName = info.goodsName,
		nickname = info.nickname,
		sTime = os.time(),
		prizeId = info.prizeId,
		status = info.status,
		source = info.source,
	}
	db.TreasurePalaceRecord:insert(data)
end

return treasurePalaceDb