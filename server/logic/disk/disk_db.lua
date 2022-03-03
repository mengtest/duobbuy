local diskDb = {}

function diskDb.setRecord(db, roleId, endTime)
	local data = {}
	data._id = roleId
	data.endTime = endTime

    local doc = {
        query = {_id = roleId},
        update = {["$set"] = data},
        upsert = true,
    }

	db.Disk:findAndModify(doc)
end

function diskDb.getRecord(db, roleId)
	local info = db.Disk:findOne({_id = roleId})
    return info
end

return diskDb