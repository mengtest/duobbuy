local resOperate = require("common.res_operate")
local dbHelp = require("common.db_help")
local roleCtrl = require("role.role_ctrl")
local configDb = require("config.config_db")
local logConst = require("game.log_const")
local diskRateConf = configDb.diskRate
local diskRateData = diskRateConf.data
local diskRateTotal = diskRateConf.total

local diskCtrl = {}
local diskConst = require("disk.disk_const")

-- 转转盘
function diskCtrl.roll(roleId)
	local rollFlag, critFlag = diskCtrl.canRoll(roleId)
	if not rollFlag then
		return DiskError.canRoll
	end
	local luckyNum = math.rand(1, diskRateTotal)
	local luckyInfo
	for _,v in ipairs(diskRateData) do
		if luckyNum <= v.weight then
			luckyInfo = v
			break
		end
	end
	if not luckyInfo then
		return DiskError.canRoll
	end
	if not critFlag then
		local critNum = math.rand(1, diskConst.maxCrit)
		if critNum > luckyInfo.crit then
			critFlag = true
		end
	end
	local award = luckyInfo.award
	if critFlag then
		award.amount = award.amount * diskConst.critRate
	end
	local ec = resOperate.send(roleId, award.goodsId, award.amount, logConst.dailyDiskFree)
	if ec ~= SystemError.success then
		return ec
	end
	local dayEndTime = roleCtrl.getDayEndTime()
	dbHelp.call("disk.setRecord", roleId, dayEndTime)
	return ec, {rollIndex = luckyInfo.id, critFlag = critFlag}
end

-- 获取是否可以转转盘, 是否必定翻倍
function diskCtrl.canRoll(roleId)
	local record = dbHelp.call("disk.getRecord", roleId)
	if not record then
		return true, true
	else
		local sec = os.time()
		return record.endTime < sec
	end
end

return diskCtrl