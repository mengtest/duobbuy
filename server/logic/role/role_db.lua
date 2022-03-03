local skynet = require("skynet")
local roleDb = {}

function roleDb.setAttrVal(db, roleId, attrName, attrVal)
    db.Role:update(
        {_id = roleId},
        {["$set"] = {[attrName] = attrVal}}
    )
end

function roleDb.getAttrVal(db, roleId, attrName)
    local ret = db.Role:findOne({_id = roleId}, {[attrName] = 1})
    return ret and ret[attrName]
end

function roleDb.incrAttrVal(db, roleId, attrName, attrVal)
    return db.Role:update(
        { ["_id"] = roleId},
        { ["$inc"] = { [attrName] = attrVal}}
    )
end

function roleDb.getFreeGoldInfo(db, roleId)
    local info = db.FreeGold:findOne({_id = roleId})
    return info
end

function roleDb.setFreeGoldInfo(db, roleId, nextTime, endTime)
	local data = {}
	data._id = roleId
	data.nextTime = nextTime
	data.endTime = endTime
	data.joinNum = 0

    local doc = {
        query = {_id = roleId},
        update = {["$set"] = data},
        upsert = true,
    }

	db.FreeGold:findAndModify(doc)
end

function roleDb.incrFreeGoldJoinNum(db, roleId, timeStep)
	return db.FreeGold:update(
        { ["_id"] = roleId},
        { ["$inc"] = { ["joinNum"] = 1 } , ["$set"] = { ["nextTime"] = timeStep } }
    )
end

function roleDb.incrOnlineSec(db, roleId, timeStep)
    return db.Role:update(
        { ["_id"] = roleId},
        { ["$inc"] = { ["onlineSec"] = timeStep}},
        true
    )
end

function roleDb.getSeting(db, roleId)
    local data = db.SetIng:findOne({_id = roleId})
    return data and data.info
end

function roleDb.setSeting(db, roleId, info)
    db.SetIng:update(
        {_id = roleId},
        {["$set"] = {info = info}},
        true
    )
end

function roleDb.isMobileLocked(db, mobileNum)
    local ret = db.Role:findOne({mobileNum = mobileNum}, {_id = 1})
    return ret and ret._id
end

function roleDb.findMobieNum(db, uid)
    local ret = db.Role:findOne({uid = uid}, {mobileNum = 1})
    return ret and ret.mobileNum
end

function roleDb.recordChangeBag(db, roleId)
    local data = {_id = roleId}
    db.BagChange:safe_insert(data)
end

function roleDb.isAwardBagChange(db, roleId)
    local ret = db.BagChange:findOne({_id = roleId})
    return ret
end

function roleDb.recordReturnAward(db, roleId, awardIndex)
    local data = {_id = roleId, awardIndex = awardIndex, sec = skynet.time()}
    db.ReturnAward:safe_insert(data)
end

function roleDb.isAwardReturn(db, roleId)
    local ret = db.ReturnAward:findOne({_id = roleId})
    return ret
end

function roleDb.sealRole(db, roleId, endTime)
    db.SealRole:update(
        {_id = roleId},
        {["$set"] = {endTime = endTime}},
        true
    )
end

function roleDb.checkIsSeal(db, roleId)
    local ret = db.SealRole:findOne({_id = roleId},{_id = false})
    return ret
end

function roleDb.cannelSealRole(db, roleId)
    db.SealRole:delete({_id = roleId})
end

function roleDb.getWeChatFollowStatus(db, roleId)
    local ret = db.WeChatFollow:findOne({_id = roleId},{_id = false})
    return ret
end

function roleDb.setWeChatFollowStatus(db, roleId, curDay)
    db.WeChatFollow:update(
        {_id = roleId},
        {["$set"] = {showDay = curDay}},
        true
    )
end

return roleDb