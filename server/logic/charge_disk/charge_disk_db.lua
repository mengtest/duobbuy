local chargeDiskDb = {}

-- 获取已抽奖次数
function chargeDiskDb.getJoinNum(db, roleId)
	local info = db.ChargeDisk:findOne({_id = roleId})
    return info and info.joinNum or 0
end

-- 添加已抽奖次数
function chargeDiskDb.incrJoinNum(db, roleId, num)
	return db.ChargeDisk:update(
        { ["_id"] = roleId},
        { ["$inc"] = { ["joinNum"] = num } },
        true
    )
end

-----------------------------------------------

-- 
function chargeDiskDb.getDiskInfo(db, roleId, round)
	local info = db.AcitivityDisk:findOne({roleId = roleId, round = round})
	return info or {}
end

function chargeDiskDb.incrChargeMoney(db, roleId, round, amount)
	db.AcitivityDisk:update(
		{ roleId = roleId, round = round },
		{ ["$inc"] = { ["chargeMoney"] = amount } },
		true
	)
end

function chargeDiskDb.setAwardIndex(db, roleId, round, awardIndex)
	db.AcitivityDisk:update(
		{ roleId = roleId, round = round },
		{ ["$set"] = { [tostring(awardIndex)] = true} },
		true
	)
end

return chargeDiskDb