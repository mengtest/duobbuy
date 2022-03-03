local luckyBagDb = {}
local context = require("common.context")
function luckyBagDb.getIncBagId(db)
	return context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "LuckyBag")
end

function luckyBagDb.getRecord(db, roleId, goodsType, showFlag, limit)
	local rets = db.LuckyBag:find({roleId = roleId, goodsType = goodsType, showFlag = showFlag}):sort({sTime=-1}):limit(limit)

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

function luckyBagDb.addRecord(db, roleId, info)
	local data = {
		_id = luckyBagDb.getIncBagId(db),
		roleId = roleId,
		goodsType = info.goodsType,
		showFlag = info.showFlag,
		goodsName = info.goodsName,
		nickname = info.nickname,
		sTime = os.time(),
		prizeId = info.prizeId,
		status = info.status,
		type = info.type or 2,
	}
	-- dump(data)
	db.LuckyBag:insert(data)
end

function luckyBagDb.getAttrVal(db, roleId, attrName)
    local ret = db.LuckyBagNum:findOne({_id = roleId}, {[attrName] = 1})
    return ret and ret[attrName]
end

function luckyBagDb.incrAttrVal(db, roleId, attrName, attrVal)
    return db.LuckyBagNum:update(
        { ["_id"] = roleId},
        { ["$inc"] = { [attrName] = attrVal}},
		{upsert = true}
    )
end

return luckyBagDb