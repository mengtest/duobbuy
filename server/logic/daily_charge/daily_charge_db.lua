local dailyChargeDb = {}
local context = require("common.context")

function dailyChargeDb.getInfo(db, roleId, month)
	local info = db.DailyRechargeInfo:findOne({roleId = roleId, month = month},{
				_id = false,
				roleId = false,
		})
	return info or {}
end

function dailyChargeDb.updateDailyChargeInfo(db, roleId, month, key, value)
	db.DailyRechargeInfo:update(
		{ roleId = roleId, month = month },
		{ ["$set"] = { [key] = value } },
		true
	)
end

function dailyChargeDb.updateChargeDays(db, roleId, month, date)
	db.DailyRechargeInfo:update(
		{ roleId = roleId, month = month },
		{ ["$set"] = { lastChargeDate = date }, ["$inc"] = { chargeDays = 1} },
		true
	)
end

function dailyChargeDb.addRecord(db, roleId, day)
	local id = context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "ContinueChargeRecord")
	local data = {
		_id = id,
		roleId = roleId,
		sTime = os.time(),
		dayType = day,
	}
	db.ContinueChargeRecord:insert(data)
end

return dailyChargeDb