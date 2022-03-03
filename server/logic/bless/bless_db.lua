local blessDb = {}
local context = require("common.context")

function blessDb.getInfo(db, roleId)
	local info = db.Bless:findOne({roleId = roleId},{
				_id = false,
				roleId = false,
		})
	return info or {}
end

function blessDb.getBlessValue(db, roleId, blessId)
	local info = db.Bless:findOne({roleId = roleId}, {[blessId] = 1})
	return info and info[tostring(blessId)]
end

function blessDb.initBlessInfo(db, roleId, info)
	local doc = {
        query = {roleId = roleId},
        update = {["$set"] = info},
        upsert = true,
    }

    db.Bless:findAndModify(doc)
end

function blessDb.updateBless(db, roleId, blessId, value)
	db.Bless:update(
		{ roleId = roleId },
		{ ["$set"] = { [tostring(blessId)] = value } },
		true
	)
end

--增加祈福成功记录
function blessDb.addRecord(db, roleId, info)
	local id = context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "BlessRecord")
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
	db.BlessRecord:insert(data)
end

function blessDb.getRecord(db, roleId, goodsType, limit)
	local rets = db.BlessRecord:find({roleId = roleId, goodsType = goodsType}):sort({sTime=-1}):limit(limit)

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

--祈福记录
function blessDb.addBlessTimesRecord(db, roleId, goodsName)
	local id = context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "BlessTimesRecord")
	local data = {
		_id = id,
		roleId = roleId,
		goodsName = goodsName,
		sTime = os.time(),
	}
	db.BlessTimesRecord:insert(data)
end

return blessDb