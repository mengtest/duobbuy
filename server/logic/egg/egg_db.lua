local eggDb = {}
local context = require("common.context")

function eggDb.getInfo(db, roleId, round)
	local info = db.Egg:findOne({roleId = roleId, round = round},{
				_id = false,
				roleId = false,
				round = false,
		})
	return info or {}
end

function eggDb.updateEggInfo(db, roleId, round, updateInfo)
	db.Egg:update(
		{ roleId = roleId, round = round },
		{ ["$set"] = updateInfo },
		true
	)
end

function eggDb.incrChargeMoney(db, roleId, round, amount)
	db.Egg:update(
		{ roleId = roleId, round = round },
		{ ["$inc"] = { ["chargeNum"] = amount } },
		true
	)
end

--增加金蛋记录
function eggDb.addRecord(db, roleId, info)
	local id = context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "EggRecord")
	local data = {
		_id = id,
		roleId = roleId,
		goodsType = info.goodsType,
		goodsName = info.goodsName,
		nickname = info.nickname,
		sTime = os.time(),
		round = info.round,
	}
	db.EggRecord:insert(data)
end


return eggDb