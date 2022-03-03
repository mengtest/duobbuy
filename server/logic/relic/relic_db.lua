local relicDb = {}
local context = require("common.context")

function relicDb.getInfo(db, roleId)
	local ret = db.Relic:findOne({_id = roleId})
	return ret or {}
end

function relicDb.updateRelicInfo(db, roleId, level)
	db.Relic:update(
		{ _id = roleId },
		{ ["$set"] = { level = level } },
		true
	)
end

function relicDb.getRecord(db, roleId, goodsType, limit)
	local rets = db.RelicRecord:find({roleId = roleId, goodsType = goodsType}):sort({sTime=-1}):limit(limit)

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

function relicDb.addRecord(db, roleId, info)
	local id = context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "RelicRecord")
	local data = {
		_id = id,
		roleId = roleId,
		goodsType = info.goodsType,
		goodsName = info.goodsName,
		nickname = info.nickname,
		sTime = os.time(),
		prizeId = info.prizeId,
		status = info.status,
	}
	db.RelicRecord:insert(data)
end


return relicDb