local miscDb = {}

function miscDb.getAllOnlineInfo(db, roleId)
	roleId = tonumber(roleId)
	local data = db.MiscOnlineInfo:findOne({ ["_id"] = roleId }) or {}
	data._id = nil
	return data
end

function miscDb.setOnlineInfo(db, roleId, onlineInfo)
	assert(onlineInfo.type)
	roleId = tonumber(roleId)
	local type = tonumber(onlineInfo.type)
	db.MiscOnlineInfo:update(
		{["_id"] = roleId},
		{["$set"] = {[tostring(type)] = onlineInfo}},
		{upsert = true}
	)
end

return miscDb