local json	   = require("json")
local logger     = require("log")
local skynet  	= require("skynet")
local dbHelp   = require("common.db_help")
local context = require("common.context")
local resCtrl  = require("common.res_operate")
local LogConst  = require("game.log_const")
local MiscConst = require("misc.misc_const")
local AwardStatus = MiscConst.AwardStatus

local configDb = require("config.config_db")
local MiscOnlineConfig = configDb.misc_online_config

local miscCtrl = {}
local EC_MISCCODE_NOT_EXIST         = 7
local EC_MISCTYPE_NOT_EXIST         = 8
local EC_MISCCODE_NOT_IN_USE_TIME   = 9
local EC_MISCCODE_HAD_USED          = 14
local EC_MISCTYPE_HAD_USE 			= 18

local EC_SUCCESS                    = 0

function miscCtrl.onLogin(roleId, accountdata)
	-- print("miscCtrl.onLogin(roleId, accountdata)")
	miscCtrl.onTick(roleId)
	
	accountInfo = accountdata or {}
	-- accountInfo.miscOnlineList = {4}
	if accountInfo and not accountInfo.miscOnlineList then 
		return
	end
	for _,miscType in pairs(accountInfo.miscOnlineList) do
		-- 特殊处理，旧的兑换码类型
		local numMiscType = miscType
		if type(numMiscType) == "string" then 
			numMiscType = tonumber(numMiscType)
		end
		if numMiscType ~= 2 and numMiscType ~= 3 then 
			miscCtrl.open(roleId, numMiscType)
		end
	end
end

-- 玩家离线
function miscCtrl.onLogout(roleId)
	-- print("miscCtrl.onLogout(roleId)")
	local allOnlineInfo = miscCtrl.getAllOnlineInfo(roleId)
	for _,onlineInfo in pairs(allOnlineInfo or{}) do
		miscCtrl.setOnlineInfo(roleId, onlineInfo)
	end
end

local function getDayFlag(sec)
	sec = sec or os.time()
	return tonumber(os.date("%Y%m%d", sec))
end

local OnlineInfoCache
function miscCtrl.getAllOnlineInfo(roleId)
	if OnlineInfoCache then 
		return OnlineInfoCache
	end 
	
	-- 没有缓存则构建缓存
	OnlineInfoCache = {}
	local allOnlineInfo = dbHelp.call("misc.getAllOnlineInfo", roleId)
	for _,onlineInfo in pairs(allOnlineInfo) do
		OnlineInfoCache[onlineInfo.type] = onlineInfo
	end
	-- dump(OnlineInfoCache)
	return OnlineInfoCache
end

function miscCtrl.setOnlineInfo(roleId, onlineInfo)
	assert(onlineInfo.type)
	OnlineInfoCache[onlineInfo.type] = onlineInfo
	dbHelp.send("misc.setOnlineInfo", roleId, onlineInfo)
end

function miscCtrl.update(roleId, onlineInfo)
	local currFlag = getDayFlag()
	
	local MiscOnlineVO = MiscOnlineConfig[onlineInfo.type] 
	if not MiscOnlineVO then return end

	for _,awardInfo in pairs(onlineInfo.award_list or {}) do
		local dayFlag = getDayFlag(onlineInfo.startAt + (awardInfo.day - 1) * 86400)
		-- 跨天重置
		if dayFlag < currFlag then
			if (awardInfo.status ~= AwardStatus.RECEIVED and awardInfo.status ~= AwardStatus.CAN_RECEIVE) then
				if awardInfo.onlineSec < MiscOnlineVO.online_time then 
					miscCtrl.open(roleId, onlineInfo.type, true)
					return
				end
			end
		end
		-- 增加在线时间
		if dayFlag == currFlag then 
			if awardInfo.status == AwardStatus.CAN_NOT_RECEIVE then 
				awardInfo.status = AwardStatus.COUNT_DOWN
			end
			awardInfo.onlineSec = awardInfo.onlineSec + 1
			-- 允许时间差
			local online_time = MiscOnlineVO.online_time - 3
			if awardInfo.onlineSec >= online_time and awardInfo.status == AwardStatus.COUNT_DOWN then 
				awardInfo.status = AwardStatus.CAN_RECEIVE
			end
		end
	end	
end

function miscCtrl.onTick(roleId)
	skynet.timeout(100, 
		function() 
			miscCtrl.onTick(roleId)
		end
	)

	local allOnlineInfo = miscCtrl.getAllOnlineInfo(roleId)
	for _,onlineInfo in pairs(allOnlineInfo) do
		if not onlineInfo.expired then 
			miscCtrl.update(roleId, onlineInfo)
		end
	end
end

function miscCtrl.open(roleId, miscType, reset)
	roleId = tonumber(roleId)
	miscType = tonumber(miscType)

	local MiscOnlineVO = MiscOnlineConfig[miscType] 
	if not MiscOnlineVO then 
		logger.Errorf("miscCtrl.open(roleId:%s, miscType:%s) MiscOnlineConfig:%s", roleId, miscType, dumpString(MiscOnlineConfig))
		return
	end
	logger.Infof("miscCtrl.open(roleId:%s, miscType:%s)", roleId, miscType)

	local allOnlineInfo = miscCtrl.getAllOnlineInfo(roleId)
	if not reset and allOnlineInfo[miscType] then 
		return 
	end

	local onlineInfo = {}
	onlineInfo.type = miscType
	onlineInfo.award_list = {}
	onlineInfo.startAt = os.time()
	for day,award in ipairs(MiscOnlineVO.award_info) do
		local award_info = {}
		award_info.day = day
		award_info.status = AwardStatus.CAN_NOT_RECEIVE
		award_info.onlineSec = 0
		table.insert(onlineInfo.award_list, award_info)
	end
	allOnlineInfo[miscType] = onlineInfo
	miscCtrl.setOnlineInfo(roleId, onlineInfo)
	-- 进行一次更新
	miscCtrl.update(roleId, onlineInfo)
end

function miscCtrl.getMiscOnlineInfo(roleId)
	local miscOnlineInfo = {}
	miscOnlineInfo.infoList = {}

	local now = os.time()
	local allOnlineInfo = miscCtrl.getAllOnlineInfo(roleId)
	for _,onlineInfo in pairs(allOnlineInfo) do
		if not onlineInfo.expired or (onlineInfo.expired and onlineInfo.expired > now) then  
			local MiscOnlineVO = MiscOnlineConfig[onlineInfo.type] 
			if not MiscOnlineVO then 
				logger.Errorf("miscCtrl.open(roleId:%s, miscType:%s) MiscOnlineConfig:%s", roleId, miscType, dumpString(MiscOnlineConfig))
				return 
			end
			local info = {}
			info.type = onlineInfo.type
			info.name = MiscOnlineVO.name
			info.online_time = MiscOnlineVO.online_time
			info.award_list = {}
			info.help = MiscOnlineVO.help
			info.startAt = onlineInfo.startAt

			for _,award in pairs(onlineInfo.award_list) do
				local awardInfo = {}
				awardInfo.day = award.day
				awardInfo.status = award.status
				-- 可领取时，发送倒计时
				if awardInfo.status == AwardStatus.COUNT_DOWN then 
					awardInfo.timestamp = skynet.time() + MiscOnlineVO.online_time - award.onlineSec
				end

				local awardData = MiscOnlineVO.award_info[award.day]
				awardInfo.award_info = {}
				awardInfo.award_info.goodsId = awardData.goodsId
				awardInfo.award_info.amount = awardData.amount
				awardInfo.award_info.currencyId = awardData.currencyId
				awardInfo.award_info.desc = awardData.desc
				table.insert(info.award_list, awardInfo)
			end

			table.insert(miscOnlineInfo.infoList, info)
		end
	end
	-- dump(miscOnlineInfo, _, 9)
	return miscOnlineInfo
end 

function miscCtrl.getMiscOnlineAward(roleId, type, day)
	local MiscOnlineVO = MiscOnlineConfig[type] 
	if not MiscOnlineVO then 
		logger.Errorf("miscCtrl.getMiscOnlineAward(roleId:%s, type:%s, day:%s)", roleId, type, day)
		return MiscError.invalidMiscInfo
	end
	local awardGood = MiscOnlineVO.award_info[day]
	if not awardGood then 
		logger.Errorf("miscCtrl.getMiscOnlineAward(roleId:%s, type:%s, day:%s)", roleId, type, day)
		return MiscError.invalidMiscInfo
	end

	local allOnlineInfo = miscCtrl.getAllOnlineInfo(roleId)
	local onlineInfo = allOnlineInfo[type]
	if not onlineInfo then 
		logger.Errorf("miscCtrl.getMiscOnlineAward(roleId:%s, type:%s, day:%s)", roleId, type, day)
		return MiscError.invalidMiscInfo
	end
	
	local awardInfo
	for _,award in pairs(onlineInfo.award_list) do
		if award.day == day then 
			awardInfo = award
			break
		end
	end

	if not awardInfo then 
		logger.Errorf("miscCtrl.getMiscOnlineAward(roleId:%s, type:%s, day:%s) awardInfo:%s", roleId, type, day, dumpString(awardInfo))
		return MiscError.invalidMiscInfo
	end

	-- 判断状态
	if awardInfo.status ~= AwardStatus.CAN_RECEIVE then 
		logger.Errorf("miscCtrl.getMiscOnlineAward(roleId:%s, type:%s, day:%s) awardInfo:%s", roleId, type, day, dumpString(awardInfo))
		return MiscError.canNotReceive
	end

	-- 奖励物品
	local goodId = awardGood.goodsId and awardGood.currencyId
	local amount = awardGood.amount
	if awardGood.rand then 
		amount = math.rand(awardGood.rand[1], awardGood.rand[2])
	end

	-- 发送 Q 币
	if day == 7 then
		-- logger.Infof("miscCtrl.getMiscOnlineAward(roleId:%s, type:%s, day:%s) goodId:%s amount:%s onlineInfo:%s", roleId, type, day, goodId, amount, dumpString(onlineInfo))
		context.sendS2S(SERVICE.RECORD, "miscOnlineComplete", roleId, type, amount)
		onlineInfo.expired = os.time() + MiscConst.expireTime
	end

	-- 修改状态
	awardInfo.status = AwardStatus.RECEIVED
	miscCtrl.setOnlineInfo(roleId, onlineInfo)

	-- 发送奖励
	if awardGood.goodsId and awardGood.amount then 
		local goodsList = {{goodsId = goodId, amount = amount}}
		resCtrl.sendList(roleId, goodsList, LogConst.miscOnlineGet)
	end
	
	local MiscOnlineAward = {}
	MiscOnlineAward.awardInfo = {}
	MiscOnlineAward.awardInfo.goodsId = awardGood.goodsId
	MiscOnlineAward.awardInfo.amount = amount
	MiscOnlineAward.awardInfo.currencyId = awardGood.currencyId
	if awardGood.name then
		MiscOnlineAward.awardInfo.desc = tostring(amount) .. awardGood.name
	end
	-- dump(MiscOnlineAward)
	return SystemError.success, MiscOnlineAward
end 

return miscCtrl