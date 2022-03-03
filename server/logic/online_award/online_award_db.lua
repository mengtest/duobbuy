local onlineAwardDb = {}


function onlineAwardDb.getOnlineInfo(db, roleId)
    local data = db.OnlineInfo:findOne({_id = roleId})
    return data
end

function onlineAwardDb.updateOnlineInfo(db, roleId, info)
    db.OnlineInfo:update(
        {["_id"] = roleId},
        {["$set"] = info},
        true
    )
end

return onlineAwardDb