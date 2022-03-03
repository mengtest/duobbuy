local morrowGiftDb = {}

function morrowGiftDb.getInfo(db, roleId)
	roleId = tonumber(roleId)
	local data = db.MorrowGift:findOne({ ["_id"] = roleId }) or {}
	return data.info
end

function morrowGiftDb.setInfo(db, roleId, morrowGiftInfo)
	roleId = tonumber(roleId)
	db.MorrowGift:update(
		{["_id"] = roleId},
		{["$set"] = {["info"] = morrowGiftInfo}},
		{upsert = true}
	)
end

return morrowGiftDb