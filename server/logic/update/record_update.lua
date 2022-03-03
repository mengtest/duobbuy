--[[
    该文件必须在record服务上执行，限于更新record
    首先通过调试控制台的list命令获取record服务地址
    然后执行以下命令:
    inject :03000012 ./logic/update/record_update.lua
    :03000012为record服务地址
]]
local codecache = require("skynet.codecache")
local hotfix = require("common.hotfix")
local context = require("common.context")
local configUpdater = require("update.config_updater")

local Updater = {}

--清理代码缓存，如果只是修复内存状态，没有更新代码，则不要调用
codecache.clear()

local command = _P.lua.command

local global    = require("config.global")
local skynet  	= require("skynet")

local oneDaySec = 86400
local openDate = global.openDate

--根据开服第几天计算要记录的时间戳
local function calRecordTimeByOpenDate(day)
	local openDateLastTime = os.time({year = openDate.year, month = openDate.month, day = openDate.day, hour = 23, min = 59, sec = 59})
	local time = (day - 1) * oneDaySec + openDateLastTime
	local date = {year = os.date('%Y',time),month = os.date('%m',time),day = os.date('%d',time),hour = os.date('%H',time),min = os.date('%M',time),sec = os.date('%S',time)}
	return date
end

local recordFightPowerDate = {
	{fightPower = 3000,recordTime = calRecordTimeByOpenDate(1)},
	{fightPower = 10000,recordTime =calRecordTimeByOpenDate(2)},
	{fightPower = 20000,recordTime =calRecordTimeByOpenDate(3)},
}

local recordUnionData = {
	{unionLv = 2,unionMemberNum = 20,recordTime = calRecordTimeByOpenDate(1)},
	{unionLv = 2,unionMemberNum = 20,recordTime = calRecordTimeByOpenDate(2)},
	{unionLv = 2,unionMemberNum = 20,recordTime = calRecordTimeByOpenDate(3)},
	{unionLv = 2,unionMemberNum = 20,recordTime = calRecordTimeByOpenDate(4)},
}


local nowTime = os.time()
for _,conf in pairs(recordFightPowerDate) do
	local leftTime = os.time(conf.recordTime)-nowTime
	print("leftTime:"..leftTime)
	skynet.timeout(leftTime * 100, function() command.recordFightPowerOverValue(conf.fightPower) end)
end
for _,conf in pairs(recordUnionData) do
	local year, month, day = conf.recordTime.year, conf.recordTime.month,conf.recordTime.day
	local cdate = string.format("%04d%02d%02d", year, month, day)
	local leftTime = os.time(conf.recordTime)-nowTime
	skynet.timeout(leftTime* 100, function() command.recordUnionData(conf.unionLv,conf.unionMemberNum,cdate) end)
end
print("updateRecord")