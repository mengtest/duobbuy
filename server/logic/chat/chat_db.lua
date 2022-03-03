local chatDb = {}

function chatDb.getForbidSpeakRoles(db)
	local forbidRoles = {}
	local roles = db.ForbidSpeakRoles:find()
	while roles:hasNext() do
		local r = roles:next()
		forbidRoles[r._id] = r.expire
	end

	return forbidRoles
end

function chatDb.setForbidRole(db, roleId, expire)
	local doc = {
		_id = roleId,
		expire = expire,
	}
	db.ForbidSpeakRoles:insert(doc)
end

function chatDb.getForbidRole(db, roleId)
	local ret = db.ForbidSpeakRoles:findOne({_id = roleId})
	ret.roleId = roleId

	return ret
end

function chatDb.deleteForbidRole(db,forbider)
	local doc = {
		query = {_id = roleId} ,
		remove = true,
	}
	db.ForbidSpeakRoles:findAndModify(doc)
end

function chatDb.getForbidenExpire(db, roleId)
	local forbid = db.ForbidSpeakRoles:findOne({_id = roleId})
	return (forbid and forbid.expire) or 0
end

return chatDb