local inviteDb = {}
local context = require("common.context")

function inviteDb.getPlayInfo(db, roleId)
	local ret = db.InvitePlay:findOne({_id = roleId}, {_id = false})
	return ret
end

function inviteDb.addPlayInfo(db, data)
	local doc = {
		_id = data.roleId,
		inviteId = data.inviteId,
		chargeAddStatus = data.chargeAddStatus,
		sTime = os.time(),
	}
	db.InvitePlay:insert(doc)
end

function inviteDb.getInviteInfo(db, roleId)
	local ret = db.Invite:findOne({_id = roleId}, {_id = false})
	return ret or {}
end

function inviteDb.updateInviteInfo(db, roleId, awardIndex)
	db.Invite:update(
		{ _id = roleId },
		{ ["$set"] = { [tostring(awardIndex)] = true } },
		true
	)
end

function inviteDb.addInviteNum(db, roleId, imeiList)
	local sTime = os.time()
	db.Invite:update(
		{ _id = roleId },
		{ ["$set"] = { ["imeiList"] = imeiList, ["sTime"] = sTime }, ["$inc"] = { ["inviteNum"] = 1 } },
		true
	)
end

function inviteDb.getChargeInfo(db, roleId)
	local ret = db.InviteCharge:findOne({_id = roleId}, {_id = false})
	return ret or {}
end

function inviteDb.updateChargeInfo(db, roleId, key, value)
	db.InviteCharge:update(
		{ _id = roleId },
		{ ["$inc"] = { [key] = value } },
		true
	)
end

function inviteDb.addChargeNum(db, roleId, chargeNum)
	local sTime = os.time()
	db.InviteCharge:update(
		{ _id = roleId },
		{ ["$inc"] = { ["chargeNum"] = chargeNum }, ["$set"] = { ["sTime"] = sTime } },
		true
	)
end


return inviteDb