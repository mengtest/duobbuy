local couponDb = {}

local context = require("common.context")

function couponDb.getInfo(db, roleId, round)
	local info = db.Coupon:findOne({roleId = roleId, round = round}, {
			_id = false,
			chargeMoney = true,
			joinTimes = true,
			cards = true,
			awardStates = true,
			excludes = true,
		})
	return info or {}
end

function couponDb.incrChargeMoney(db, roleId, round, amount)
	db.Coupon:update(
		{ roleId = roleId, round = round },
		{ ["$inc"] = { ["chargeMoney"] = amount } },
		true
	)
end

function couponDb.getAwardStates(db, roleId, round)
	local info = db.Coupon:findOne({roleId = roleId, round = round}, {
			_id = false,
			awardStates = true,
		})
	return info and info.awardStates
end 

function couponDb.updateAwardStates(db, roleId, round, awardStates)
	db.Coupon:update(
		{ roleId = roleId, round = round },
		{ ["$set"] = { ["awardStates"] = awardStates } },
		true
	)
end

function couponDb.openCard(db, roleId, round, info)
	db.Coupon:update(
		{ roleId = roleId, round = round },
		{ ["$set"] = { 
			["joinTimes"] = info.joinTimes,
			["cards"] = info.cards, 
			["awardStates"] = info.awardStates,
			["excludes"] = info.excludes } },
		false
	)
end

function couponDb.insertPrize(db, info)
	local id = context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "CouponPrize")
	local data = {
		_id = id,
		roleId = info.roleId,
		goodsType = info.goodsType,
		goodsName = info.goodsName,
		nickname = info.nickname,
		sTime = info.time,
		prizeId = info.prizeId,
		status = info.status,
		round = info.round,
	}
	db.CouponPrize:insert(data)
end

function couponDb.getPrizes(db, roleId, round, goodsType, limit)
	local rets = db.CouponPrize:find({roleId = roleId, round = round, goodsType = goodsType}):sort({sTime=-1}):limit(limit)

	local results = {}
    while rets:hasNext() do
        local result = rets:next()
        results[#results + 1] = {
			goodsName = result.goodsName,
			time = result.sTime,
			status = result.status
        }
    end

    return results
end

return couponDb