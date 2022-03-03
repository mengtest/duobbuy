local shareDb = {}

function shareDb.setRecord(db, roleId, endTime)
	local data = {}
	data._id = roleId
	data.endTime = endTime

    local doc = {
        query = {_id = roleId},
        update = {["$set"] = data},
        upsert = true,
    }

	db.Share:findAndModify(doc)
end

function shareDb.getRecord(db, roleId)
	local info = db.Share:findOne({_id = roleId})
    return info
end

return shareDb