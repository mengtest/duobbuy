local boxDb = {}

function boxDb.getOpenNum(db, roleId, boxIndex)
	local ret = db.Box:findOne({roleId = roleId, boxIndex = boxIndex}, {num = 1})
	return ret and ret.num or 0
end

function boxDb.incrOpenNum(db, roleId, boxIndex, num)
	db.Box:update(
		{roleId = roleId, boxIndex = boxIndex},
		{["$inc"] = { num = num}},
		true
	)
end

function boxDb.getNumInitFlag(db, roleId)
	local ret = db.BoxInit:findOne({roleId = roleId}, {flag = 1})
	return ret and ret.flag
end

function boxDb.setInitFlag(db, roleId)
	db.BoxInit:update(
		{roleId = roleId},
		{["$set"] = { flag = true}},
		true
	)
end

return boxDb