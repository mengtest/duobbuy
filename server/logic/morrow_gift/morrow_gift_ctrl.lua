local logger = require("log")
local skynet = require("skynet")
local dbHelp = require ("common.db_help")
local context = require("common.context")

local resCtrl = require("common.res_operate")
local logConst = require("game.log_const")
local morrowGiftConst = require("morrow_gift.morrow_gift_const")

local morrowGiftCtrl = {}

local OneDaySec = 86400 -- 	一天的秒数
local OneHourSec = 3600	--	一小时的秒数
local OneMinSec = 60 	--	一分钟的秒数

-- 获得下次可领取的时间
function morrowGiftCtrl.getNextReceiveAt(sec)
	-- return skynet.time() + 10
	sec = sec or os.time()
	local timeDate = os.date("*t", sec)
	local dayEndTime = sec + OneDaySec - (timeDate.hour * OneHourSec + timeDate.min * OneMinSec + timeDate.sec)
	local nextReceiveAt = dayEndTime + morrowGiftConst.receiveTime
	return nextReceiveAt
end

local morrowGiftInfo
function morrowGiftCtrl.getInfo(roleId)
	-- 返回缓存
	if morrowGiftInfo and not table.empty(morrowGiftInfo) then 
		return morrowGiftInfo
	end 

	-- 获取数据库记录
	morrowGiftInfo =  dbHelp.call("morrowGift.getInfo", roleId)
	if morrowGiftInfo and not table.empty(morrowGiftInfo) then 
		return morrowGiftInfo
	end

	-- 找不到记录初始化数据
	morrowGiftInfo = {}
	morrowGiftInfo.receiveTime = morrowGiftCtrl.getNextReceiveAt()
	morrowGiftInfo.day = 0
	dbHelp.send("morrowGift.setInfo", roleId, morrowGiftInfo)
	return morrowGiftInfo
end

function morrowGiftCtrl.getClientInfo(roleId)
	local morrowGiftInfo = clone(morrowGiftCtrl.getInfo(roleId))
	morrowGiftInfo.lastDay = morrowGiftConst.lastDay
	morrowGiftInfo.awardList = morrowGiftConst.awardList
	return SystemError.success, morrowGiftInfo
end

function morrowGiftCtrl.getAward(roleId)
	local morrowGiftInfo = morrowGiftCtrl.getInfo(roleId)

	-- 天数限制
	if morrowGiftInfo.day >= morrowGiftConst.lastDay then 
		logger.Errorf("morrowGiftCtrl.getAward(roleId:%s) morrowGiftInfo:%s", roleId, dumpString(morrowGiftInfo))
		return MorrowGiftError.giftIsReceived
	end

	-- 时间限制
	local now = skynet.time()
	-- 允许5秒的误差
	local diffTime = 5 
	if (morrowGiftInfo.receiveTime - diffTime) > now then 
		logger.Errorf("morrowGiftCtrl.getAward(roleId:%s) morrowGiftInfo:%s", roleId, dumpString(morrowGiftInfo))
		return MorrowGiftError.invalidReceivedTime
	end

	-- 校验通过，保存数据库
	morrowGiftInfo.day = morrowGiftInfo.day + 1
	morrowGiftInfo.receiveTime = morrowGiftCtrl.getNextReceiveAt()
	dbHelp.send("morrowGift.setInfo", roleId, morrowGiftInfo)

	-- 发送奖励
	if not table.empty(morrowGiftConst.awardList or {}) then
		resCtrl.sendList(roleId, morrowGiftConst.awardList, logConst.morrowGiftGet)
	end	

	return morrowGiftCtrl.getClientInfo(roleId)
end

return morrowGiftCtrl