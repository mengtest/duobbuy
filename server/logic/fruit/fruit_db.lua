local fruitDb = {}

-- 获取免费抽奖信息
function fruitDb.getFreeInfo(db, roleId)
	local info = db.Fruit:findOne({_id = roleId})
    return info
end

-- 设置免费抽奖信息
function fruitDb.incrPrice(db, roleId, num)
	db.Fruit:update(
        { ["_id"] = roleId},
        { ["$inc"] = { ["price"] = num } },
        true
    )
end

-- 添加免费使用次数
function fruitDb.incrUseFreeNum(db, roleId, num)
	return db.Fruit:update(
        { ["_id"] = roleId},
        { ["$inc"] = { ["useFreeNum"] = num } },
        true
    )
end

return fruitDb