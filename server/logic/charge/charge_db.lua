local chargeDb = {}

-- 记录玩家充值
function chargeDb.recordCharge(db, roleId, logInfo)
	logInfo.roleId = roleId
	db.Charge:insert(logInfo)
	db.RecordLog:insert(logInfo)
end

-- 判断玩家是否参与某类型充值
function chargeDb.hasRoleIndexReocrd(db, roleId, shopItemIndex)
	local ret = db.Charge:findOne({roleId = roleId, shopItemIndex = shopItemIndex}, {_id = 1})
	return ret and ret._id
end

-- 获取玩家充值记录
function chargeDb.getRoleRecords(db, roleId)
	local records = {}
	local rets = db.Charge:find({roleId = roleId})
	while rets:hasNext() do
		local r = rets:next()
		records[#records+1] = r
	end

	return records
end

-- 获取玩家充值金额
function chargeDb.getRoleChargeAmount(db, roleId, sTime, eTime)
	local cTime = {}
	if sTime then
		cTime["$gte"] = sTime
	end
	if eTime then
		cTime["$lte"] = eTime
	end
	if table.empty(cTime) then
		cTime = nil
	end
	local rets = db.Charge:find({roleId = roleId, cTime = cTime}, {price = 1})
	local total = 0
	while rets:hasNext() do
		local r = rets:next()
		total = total + r.price
	end
	return total
end

-- 记录玩家福袋
function chargeDb.recordShopBag(db, roleId, shopItemIndex, date)
	local data = {
		roleId = roleId,
		shopItemIndex = shopItemIndex,
		date = date,
	}
	db.ShopBag:insert(data)
end

-- 查询玩家福袋记录
function chargeDb.hasRoleShopBag(db, roleId, shopItemIndex, date)
	local ret = db.ShopBag:findOne({roleId = roleId, shopItemIndex = shopItemIndex, date = date}, {_id = 1})
	return ret and ret._id
end

-- 金币执行日志
function chargeDb.recordOp(db, sec, roleId, shopItemIndex, flag)
	local data = {
		sec = sec,
		roleId = roleId,
		shopItemIndex = shopItemIndex,
		flag = flag,
	}
	db.ChargeOp:insert(data)
end

-- 判断玩家是否参与某类型充值
function chargeDb.getRoleChargeIndexNum(db, roleId, shopItemIndex)
	local ret = db.Charge:find({roleId = roleId, shopItemIndex = shopItemIndex}, {_id = 1}):count()
	return ret
end


--记录玩家月卡剩余天数
function chargeDb.setMonthCardDays(db,roleId,days)
	local data = {_id = roleId,days = days}
	db.MonthCard:insert(data)
end

--查找玩家月卡剩余天数
function chargeDb.getMonthCardDays(db,roleId)
	local ret = db.MonthCard:findOne({_id = roleId})
	return ret and ret['days']
end

--增加玩家月卡剩余天数
function chargeDb.incryMonthCardDays(db,roleId,addDays)
	return db.MonthCard:update(
		{["_id"] = roleId},
		{["$inc"] = {["days"] = addDays}}
	)
end

--獲取所有玩家的月卡剩餘天數
function chargeDb.getAllMonthCardDays(db)
	local allMonthCardDaysInfo = {}
	local monthCards = db.MonthCard:find({days = {["$gt"] = 0}})
	while monthCards:hasNext() do
		local info = monthCards:next()
		allMonthCardDaysInfo[info._id] = info.days
	end

	return allMonthCardDaysInfo
end




--查找玩家礼包剩余天数
function chargeDb.getGiftInfoIndex(db,roleId)
	roleId = tonumber(roleId)

	local data = db.Gift:findOne({_id = roleId}) or {}
	local giftInfoIndex = {}
	for giftId,days in pairs(data.giftInfoIndex or {}) do
		giftInfoIndex[tonumber(giftId)] = days
	end
	-- dump(giftInfoIndex)
	return giftInfoIndex
end

--增加玩家礼包剩余天数（addDays 为负时表示减少天数）
function chargeDb.incryGiftDays(db,roleId,giftId,addDays)
	roleId = tonumber(roleId)

	local data = db.Gift:findOne({_id = roleId}) or {}
	local giftInfoIndex = data.giftInfoIndex or {}
	giftInfoIndex[tostring(giftId)] = giftInfoIndex[tostring(giftId)] or 0
	giftInfoIndex[tostring(giftId)] = giftInfoIndex[tostring(giftId)] + addDays
	db.Gift:update(
		{["_id"] = roleId},
		{["$set"] = {["giftInfoIndex"] = giftInfoIndex}},
		{upsert = true}
	)
end

--获取所有玩家的礼包剩余天数
function chargeDb.getAllGiftInfoList(db)
	local AllGiftInfoList = {}
	local allPlayerGiftInfo = db.Gift:find({})
	while allPlayerGiftInfo:hasNext() do
		local data = allPlayerGiftInfo:next()
		local playerGiftInfoIndex = {}
		for giftId,days in pairs(data.giftInfoIndex or {}) do
			playerGiftInfoIndex[tonumber(giftId)] = days
		end
		AllGiftInfoList[tonumber(data._id)] = playerGiftInfoIndex
	end
	-- dump(AllGiftInfoList)
	return AllGiftInfoList
end


return chargeDb