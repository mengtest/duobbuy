local crazyBoxDb = {}
local context = require("common.context")

function crazyBoxDb.getInfo(db, roleId, round)
	local info = db.CrazyBox:findOne({roleId = roleId, round = round},{
				_id = false,
				roleId = false,
				round = false,
		})
	return info or {}
end

-- function crazyBoxDb.updateCrazyBoxInfos(db, roleId, round, updateInfo)
-- 	for k,v in pairs(updateInfo) do
-- 		crazyBoxDb.updateCrazyBoxInfo(db, roleId, round, k, v)
-- 	end
-- end

function crazyBoxDb.updateCrazyBoxInfo(db, roleId, round, updateInfo)
	db.CrazyBox:update(
		{ roleId = roleId, round = round },
		{ ["$set"] = updateInfo },
		true
	)
end

function crazyBoxDb.incrChargeMoney(db, roleId, round, amount)
	db.CrazyBox:update(
		{ roleId = roleId, round = round },
		{ ["$inc"] = { ["chargeNum"] = amount } },
		true
	)
end

--增加祈福记录
function crazyBoxDb.addRecord(db, roleId, info)
	local id = context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "CrazyBoxRecord")
	local data = {
		_id = id,
		roleId = roleId,
		goodsType = info.goodsType,
		goodsName = info.goodsName,
		nickname = info.nickname,
		sTime = os.time(),
		prizeId = info.prizeId,
		status = info.status,
		cycle = info.cycle,
		round = info.round,
	}
	db.CrazyBoxRecord:insert(data)
end


return crazyBoxDb