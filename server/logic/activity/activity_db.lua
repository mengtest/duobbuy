local activityDb = {}

function activityDb.recordDailyAward(db, roleId, day, awardIndex)
    local doc = {
        query = {roleId = roleId, day = day},
        update = {["$set"] = {[tostring(awardIndex)] = true}},
        upsert = true,
    }

	db.RechargeDailyAward:findAndModify(doc)
end

function activityDb.recordDailyPrice(db, roleId, day, price)
    local doc = {
        query = {roleId = roleId, day = day},
        update = {["$inc"] = {price = price}},
        upsert = true,
    }

	db.RechargeDailyAward:findAndModify(doc)
end

function activityDb.getDailyRechargeInfo(db, roleId, day)
	local ret = db.RechargeDailyAward:findOne({roleId = roleId, day = day})
	return ret or {}
end

function activityDb.recordRoundAward(db, roleId, round, awardIndex)
    local doc = {
        query = {roleId = roleId, round = round},
        update = {["$set"] = {[tostring(awardIndex)] = true}},
        upsert = true,
    }

	db.RechargeRoundAward:findAndModify(doc)
end

function activityDb.recordRoundPrice(db, roleId, round, price)
    local doc = {
        query = {roleId = roleId, round = round},
        update = {["$inc"] = {price = price}},
        upsert = true,
    }

	db.RechargeRoundAward:findAndModify(doc)
end

function activityDb.getRoundRechargeInfo(db, roleId, round)
	local ret = db.RechargeRoundAward:findOne({roleId = roleId, round = round})
	return ret or {}
end

function activityDb.getDailyHandle(db, day)
	local records = db.RechargeDailyAward:find({day = day})
	local result = {}
	while records:hasNext() do
		local r = records:next()
		result[#result+1] = r
	end
	return result
end

function activityDb.getRoundHandle(db, round)
	local records = db.RechargeRoundAward:find({round = round})
	local result = {}
	while records:hasNext() do
		local r = records:next()
		result[#result+1] = r
	end
	return result
end

-----------------------限时炮塔-------------------------------------

function activityDb.setGunEndTime(db, roleId, gunId, endSec)
	local doc = {
        query = {roleId = roleId},
        update = {["$set"] = {[tostring(gunId)] = endSec}},
        upsert = true,
    }

	db.GunAge:findAndModify(doc)
end

function activityDb.getGunEndInfo(db, roleId)
	local ret = db.GunAge:findOne({roleId = roleId})
	return ret or {}
end

function activityDb.incrGunEndTime(db, roleId, gunId, step)
	local doc = {
        query = {roleId = roleId},
        update = {["$inc"] = {[tostring(gunId)] = step}},
    }

	db.GunAge:findAndModify(doc)
end

return activityDb