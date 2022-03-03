local wishPoolDb = {}
local context = require("common.context")
-- function wishPoolDb.getIncId(db)
-- 	return context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "WishPool")
-- end

-- --获取许愿信息
-- function wishPoolDb.getRecord(db, roleId, round, goodsType, showFlag, limit)
-- 	local rets = db.WishPool:find({roleId = roleId, goodsType = goodsType, showFlag = showFlag, round = round}):sort({sTime=-1}):limit(limit)

-- 	local results = {}
--     while rets:hasNext() do
--         local result = rets:next()
--         results[#results + 1] = {
--         	roleId = result.roleId,
--         	goodsType = result.goodsType,
-- 			showFlag = result.showFlag,
-- 			goodsName = result.goodsName,
-- 			nickname = result.nickname,
-- 			time = result.sTime,
-- 			status = result.status
--         }
--     end

--     return results
-- end

-- --增加许愿记录
-- function wishPoolDb.addRecord(db, roleId, info)
-- 	local data = {
-- 		_id = wishPoolDb.getIncId(db),
-- 		roleId = roleId,
-- 		goodsType = info.goodsType,
-- 		showFlag = info.showFlag,
-- 		goodsName = info.goodsName,
-- 		nickname = info.nickname,
-- 		sTime = os.time(),
-- 		prizeId = info.prizeId,
-- 		status = info.status,
-- 		round = info.round,
-- 	}
-- 	db.WishPool:insert(data)
-- end


-- --初始化许愿池所有奖励的数量信息
-- function wishPoolDb.initInfo(db, info)
-- 	if not table.empty(info) then
-- 		for k,data in pairs(info) do
-- 			db.WishPoolTotal:insert(data)
-- 		end
-- 	end
-- end

-- --重置许愿池所有奖励的数量信息
-- function wishPoolDb.resetInfo(db, round, info)
-- 	if not table.empty(info) then
-- 		for k,data in pairs(info) do
-- 			db.WishPoolTotal:update(
-- 				{["awardId"] = data.awardId, ["round"] = round},
-- 				{["$set"] = {["num"] = data.num}}
-- 			)
-- 		end
-- 	end
-- end

-- --修改许愿池某奖励的数量
-- function wishPoolDb.incryInfo(db,id,round,num)
-- 	return db.WishPoolTotal:update(
-- 		{["awardId"] = id,["round"] = round},
-- 		{["$inc"] = {["num"] = num}}
-- 	)
-- end

-- --获取许愿池奖励的数量信息
-- function wishPoolDb.getInfo(db, round, display,sort)
-- 	local rets = db.WishPoolTotal:find({display = display, round = round}):sort(sort)
-- 	local results = {}
--     while rets:hasNext() do
--         local result = rets:next()
--         results[#results+ 1] = result
--     end
--     return results
-- end

-- --获取许愿池剩余奖励数量数组
-- function wishPoolDb.getNumInfo(db, round)
-- 	local result = db.WishPoolTotal:find({round = round})
-- 	local leftNum = 0
-- 	while result:hasNext() do
-- 		local res = result:next()
-- 		leftNum = leftNum + res.num
-- 	end
-- 	return leftNum
-- end

-- --判断某一期奖励信息是否存在
-- function wishPoolDb.judgeRoundExists(db, round)
-- 	local result = db.WishPoolTotal:find({round = round}):count()
-- 	if result > 0 then 
-- 		return true
-- 	else
-- 		return false
-- 	end
-- end

function wishPoolDb.initWishPoolInfo(db, info)
	for k,data in pairs(info) do
		db.WishPoolTotal:safe_insert(data)
	end
end

function wishPoolDb.resetInfo(db, info)
	for k,data in pairs(info) do
		db.WishPoolTotal:update(
			{["awardId"] = data.awardId, ["round"] = data.round},
			{["$set"] = {["num"] = data.num}}
		)
	end
end

function wishPoolDb.incrInfo(db, round, awardId, num)
	db.WishPoolTotal:update(
		{["awardId"] = awardId, ["round"] = round},
		{["$inc"] = {["num"] = num}}
	)
end

function wishPoolDb.getInfo(db, round)
	local rets = db.WishPoolTotal:find({round = round})
	local results = {}
    while rets:hasNext() do
        local result = rets:next()
        results[#results+ 1] = result
    end
    return results
end

function wishPoolDb.getRecord(db, roleId, round, goodsType, limit)
	local rets = db.WishPool:find({roleId = roleId, goodsType = goodsType, round = round}):sort({sTime=-1}):limit(limit)

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

function wishPoolDb.addRecord(db, roleId, info)
	local id = context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "WishPool")
	local data = {
		_id = id,
		roleId = roleId,
		goodsType = info.goodsType,
		showFlag = info.showFlag,
		goodsName = info.goodsName,
		nickname = info.nickname,
		sTime = os.time(),
		prizeId = info.prizeId,
		status = info.status,
		round = info.round,
	}
	db.WishPool:insert(data)
end



return wishPoolDb