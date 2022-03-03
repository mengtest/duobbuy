local signDiskDb = {}

--获取玩家某个年月的累计签到抽奖天数
function signDiskDb.getTotalSignDays(db, roleId, yMonth)
	local days = db.SignDisk:find({roleId = roleId, yMonth = yMonth}):count()
	return days
end

--判断玩家某天是否已抽奖
function signDiskDb.judgeHadSignDrawByDay(db, roleId, day)
	local record = db.SignDisk:findOne({roleId = roleId, day = day})
	if record then
		return true
	else 
		return false
	end
end

--增加玩家抽奖记录
function signDiskDb.addDrawRecord(db, roleId, yMonth, day)
	local info = {
		roleId = roleId,
		yMonth = yMonth,
		day = day,
	}
	db.SignDisk:safe_insert(info)
end

--初始化累计签到状态
function signDiskDb.setTotalSignInfo(db, roleId, yMonth, info)
	local infos = {roleId = roleId, yMonth = yMonth, info = info}
	db.SignTotal:safe_insert(infos)
end

--获取累计签到状态信息
function signDiskDb.getTotalSignInfo(db, roleId, yMonth)
	local ret = db.SignTotal:findOne({roleId = roleId, yMonth = yMonth})
	return ret and ret.info
end

--更新累计签到状态
function signDiskDb.updateTotalSignInfo(db, roleId, yMonth, info)
	db.SignTotal:update(
		{roleId = roleId, yMonth = yMonth},
		{["$set"] = {["info"] = info}}
	)
end

return signDiskDb