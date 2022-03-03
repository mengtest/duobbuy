local logger = require("log")
local skynet = require("skynet")
local dbHelp = require ("common.db_help")
local context = require("common.context")

local roleCtrl = require("role.role_ctrl")
local resCtrl = require("common.res_operate")
local logConst = require("game.log_const")

local configDb = require("config.config_db")
local QBSignConfig = configDb.qb_sign


local signCtrl = {}
local accountInfo


-- 在线时间要求
local OnlineLimit = 3600

-- 获得当天是第几天（从1970.1.1开始，转换时区）
function signCtrl.getCurrDay()
	local time = skynet.time()
	local timezone = tonumber(os.date("%z", 0)) / 100
	time = time + timezone * 60 * 60
	local day = math.floor(time / 86400) + 1
	return day
end

-- 获得签到信息
local SignCache 
function signCtrl.getSignInfo(roleId)
	-- 没有缓存则构建缓存
	if not SignCache then
		SignCache = {}
		local SignData = dbHelp.call("sign.getSignInfo", roleId)
		if SignData then
			SignCache = {}
			SignCache.dayIndex = {}
			for realDay,dayInfo in pairs(SignData.dayIndex) do
				SignCache.dayIndex[tonumber(realDay)] = dayInfo
			end
		end
	end

	-- test
	-- local currDay = signCtrl.getCurrDay()
	-- SignCache = {}
	-- SignCache.dayIndex = {}
	-- for i=1,7 do
	-- 	SignCache.dayIndex[currDay - (7 - i + 1)] = {isReceived = 0, day = i, onlineSec = 3600}
	-- end
		
	-- dump(SignCache)
	return SignCache
end

function signCtrl.updateSignInfo(roleId, signInfo)
	SignCache = signInfo
	dbHelp.call("sign.setSignInfo", roleId, signInfo)
end


-- 玩家登陆
function signCtrl.onLogin(roleId, accountdata)
	signCtrl.onTick(roleId)

	accountInfo = accountdata or {}
	-- accountInfo.couponCode = "111"
	-- accountInfo.couponSelect = 3
	if accountInfo and not accountInfo.couponCode then 
		return
	end

	local signInfo = signCtrl.getSignInfo(roleId)
	if not signInfo or table.empty(signInfo) then
		signCtrl.open(roleId, accountInfo.couponCode, accountInfo.couponSelect)
	end
end

-- 玩家离线
function signCtrl.onLogout(roleId)
	local signInfo = signCtrl.getSignInfo(roleId)
	if signInfo and not table.empty(signInfo) then
		signCtrl.updateSignInfo(roleId, signInfo)
	end
end

function signCtrl.onTick(roleId)
	skynet.timeout(100, 
		function() 
			signCtrl.onTick(roleId)
		end
	)
	local signInfo = signCtrl.getSignInfo(roleId)
	if not signInfo or table.empty(signInfo) then
		return
	end

	-- 之前有不满足的，重置
	local currDay = signCtrl.getCurrDay()
	for realDay,dayInfo in pairs(signInfo.dayIndex) do
		if realDay < currDay then
			if dayInfo.isReceived == 0 and dayInfo.onlineSec < OnlineLimit then
				-- print("currDay:"..currDay)
				-- dump(signInfo)
				signCtrl.reset(roleId)
				return
			end
		end
	end

	local dayInfo = signInfo.dayIndex[currDay]
	if dayInfo then
		dayInfo.onlineSec = dayInfo.onlineSec + 1
	end
end

-- 重置状态
function signCtrl.reset(roleId)
	local signInfo = signCtrl.getSignInfo(roleId)
	signInfo = {}
	signInfo.dayIndex = {}

	-- 保存数据
	local currDay = signCtrl.getCurrDay()
	for _,QBSignVO in pairs(QBSignConfig) do
		local day = currDay + QBSignVO.day - 1
		signInfo.dayIndex[day] = {day = QBSignVO.day, onlineSec = 0, isReceived = 0}
	end
	signCtrl.updateSignInfo(roleId, signInfo)
end

-- 激活每日登陆活动
function signCtrl.open(roleId, miscCode, couponSelect)
	-- print("signCtrl.open(roleId, miscCode) roleId:"..roleId.." miscCode:"..miscCode)
	accountInfo.couponCode = miscCode
	accountInfo.couponSelect = couponSelect

	local signInfo = signCtrl.getSignInfo(roleId)
	if signInfo and not table.empty(signInfo) then
		return
	end	
	signCtrl.reset(roleId)
	return SystemError.success
end


function signCtrl.getInfo(roleId)
	if accountInfo and not accountInfo.couponCode then 
		return
	end

	-- print("signCtrl.getInfo(roleId) roleId:"..roleId)
	local signInfo = signCtrl.getSignInfo(roleId)
	
	-- 活动是否存在
	if not signInfo or table.empty(signInfo) then
		return
	end

	-- 活动是否结束
	local isOver = true
	for _,dayInfo in pairs(signInfo.dayIndex) do
		if dayInfo.isReceived == 0 then
			isOver = false
		end
	end
	if isOver then
		return {miscCode = accountInfo.couponCode, codeType = accountInfo.couponSelect}
	end

	local signData = {}
	signData.list = {}
	for realDay,dayInfo in pairs(signInfo.dayIndex) do
		local day = {}
		-- 第几天
		day.day = dayInfo.day
		-- 状态 1：已经领取；2:可领取；3：倒计时；4：不可领取
		day.status = 4

		if dayInfo.isReceived == 1 then
			day.status = 1
		elseif dayInfo.onlineSec >= OnlineLimit then
			day.status = 2
		elseif realDay == signCtrl.getCurrDay() then
			day.status = 3
			day.timestamp = skynet.time() + OnlineLimit - dayInfo.onlineSec
		else
			day.status = 4
		end
		table.insert(signData.list, day)
	end

	signData.miscCode = accountInfo.couponCode
	signData.codeType = accountInfo.couponSelect
	-- dump(signData)
	return signData
end

function signCtrl.getDayAward(roleId, day)
	-- print("signCtrl.getDayAward(roleId, day) roleId:", roleId, " day:", day)
	local signInfo = signCtrl.getSignInfo(roleId)
	
	-- 活动是否存在
	if not signInfo or table.empty(signInfo) or table.empty(signInfo) then
		return QBSignError.notFindConfig
	end

	local QBSignVO
	for _,otherQBSignVO in pairs(QBSignConfig) do
		if day == otherQBSignVO.day then
			QBSignVO = otherQBSignVO
		end
	end
	if not QBSignVO then
		return QBSignError.notFindConfig
	end

	local allowReceive = false
	for _,dayInfo in pairs(signInfo.dayIndex) do
		if dayInfo.day == day and dayInfo.isReceived == 0 then
			-- 两秒钟误差
			if dayInfo.onlineSec >= (OnlineLimit - 2) then
				dayInfo.isReceived = 1
				allowReceive = true
			end
		end
	end

	if not allowReceive then
		logger.Errorf("signCtrl.getDayAward(roleId:%s, day:%s) signInfo:%s", roleId, day, dumpString(signInfo))
		return QBSignError.canNotReceive
	end

	-- 保存数据
	signCtrl.updateSignInfo(roleId, signInfo)

	-- 发送奖励
	local goodsList = {}
	for _,award in pairs(QBSignVO.award or {}) do
		if award.goodsId then
			local goodsInfo = {}
			goodsInfo.goodsId = award.goodsId
			goodsInfo.amount = award.amount
			table.insert(goodsList, goodsInfo)
		end
	end
	if not table.empty(goodsList) then
		resCtrl.sendList(roleId, goodsList, logConst.signDayGet)
	end	

	-- 发送 Q 币
	if day == 7 then
		logger.Infof("signCtrl.getDayAward(roleId:%s, day:%s) addCouponOrderInfo:%s couponSelect:%s", roleId, day, accountInfo.couponCode, accountInfo.couponSelect)
		context.sendS2S(SERVICE.RECORD, "addCouponOrderInfo", roleId, accountInfo.couponSelect)
	end
	return SystemError.success
end


function signCtrl.getWeekAward(roleId, index)
	return SystemError.success
end

return signCtrl