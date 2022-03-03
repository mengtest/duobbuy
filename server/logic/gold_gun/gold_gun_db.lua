local goldGunDb = {}
local context = require("common.context")

function goldGunDb.addRecord(db, roleId, info)
	local id = context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "GoldGunPrizeRecord")
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
	db.GoldGunPrizeRecord:insert(data)
end

function goldGunDb.getRecord(db, roleId, goodsType, limit)
	local rets = db.GoldGunPrizeRecord:find({roleId = roleId, goodsType = goodsType}):sort({sTime=-1}):limit(limit)

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

return goldGunDb