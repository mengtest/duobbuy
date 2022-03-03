local context = require("common.context")
local skynet = require("skynet")
local logger = require("log")
local logConst = require("game.log_const")
local language 	= require("language.language")
local roleConst = require("role.role_const")
local fundConst = require("fund.fund_const")
local chargeCtrl = require("charge.charge_ctrl")
local dbHelp = require("common.db_help")
local json = require("json")
local portalCtrl = {}

function portalCtrl.charge(roleId, shopItemIndex, accountId, sign, orderNum)
	local ec = context.callS2S(SERVICE.CHARGE, "buyItem", roleId, shopItemIndex, sign, orderNum)
	return ec
end

function portalCtrl.sendFundResult(roleId, nickname, amount, goodsName, leftSec, prizeId, round, roleIdList)
	logger.Debugf("portalCtrl.sendFundResult roleId:%s nickname:%s prizeId:%s amount:%s goodsName:%s roleIdList:%s", roleId, nickname, prizeId, amount, goodsName, dumpString(roleIdList))
	
	-- skynet.timeout(100 , function()
	skynet.timeout(leftSec * 100 , function()
		context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 6, words = {nickname, amount, goodsName}})

		local roleId = tonumber(roleId)
		local prizeId = tonumber(prizeId)
		local round = tonumber(round)
		local roleIdList = json.decode(roleIdList)
		if type(roleIdList) == "table" and not table.empty(roleIdList) then 
			context.sendS2S(SERVICE.STATISTIC, "recordFundResult", prizeId, round, roleId, roleIdList, goodsName)
		end 
	end)
	return SystemError.success
end

function portalCtrl.sendFundResource(roleId, nickname, amount, goodsName, leftSec, goldAmount, prizeId, round, roleIdList)
	logger.Debugf("portalCtrl.sendFundResource roleId:%s nickname:%s amount:%s prizeId:%d goodsName:%s goldAmount:%s roleIdList:%s", roleId, nickname, amount, prizeId, goodsName, goldAmount, dumpString(roleIdList))
	-- skynet.timeout(100 , function()
	skynet.timeout(leftSec * 100 , function()
		local roleId = tonumber(roleId)
		local goldAmount = tonumber(goldAmount)
		local prizeId = tonumber(prizeId)
		local round = tonumber(round)
		local roleIdList = json.decode(roleIdList)

		-- 跑马灯
		context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 6, words = {nickname, amount, goodsName}})
		
		-- 发送资源
		local source = logConst.fundGet
		if prizeId == fundConst.newPlayerPrizeId then 
			source = logConst.newPlayerFundGet
		end
		chargeCtrl.sendGoods(roleId, {{goodsId = roleConst.GOLD_ID, amount = goldAmount}}, source)
		
		-- 发送夺宝统计
		if type(roleIdList) == "table" and not table.empty(roleIdList) then 
			context.sendS2S(SERVICE.STATISTIC, "recordFundResult", prizeId, round, roleId, roleIdList, goodsName)
		end
	end)

	return SystemError.success
end

function portalCtrl.sendExchangeResult(nickname, price, title)
	logger.Debugf("portalCtrl.sendExchangeResult(nickname:%s, price:%s, title:%s)", nickname, price, title)
	context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 2, words = {nickname, price, title}})
	return SystemError.success
end

--[[
	发放道具列表
	@param roleId 		发放的道具列表
	@param goodsList 	发放的道具列表
		goodsList = {
			{goodsId = xxx, amount = xxx},
			{gunId = xxx, time = xxx},
			...
		}
	@param source 		道具操作来源
]]
function portalCtrl.sendResList(roleId, goodsList, source)
	local roleId = tonumber(roleId)
	local goodsList = json.decode(goodsList)
	local source = tonumber(source)
	if not roleId or table.empty(goodsList) or not source then
		return
	end
	
	local goodsInfoList = {}
	for _,goods in pairs(goodsList) do
		if goods.goodsId and goods.goodsId > 0 and goods.amount and goods.amount > 0 then
			table.insert(goodsInfoList, {goodsId = goods.goodsId, amount = goods.amount})
		end 
		if goods.gunId and goods.gunId > 0 and goods.time and  goods.time >= 0 then
			table.insert(goodsInfoList, {gunId = goods.gunId, time = goods.time})
		end
	end
	if table.empty(goodsInfoList) then
		return
	end
	chargeCtrl.sendGoods(roleId, goodsInfoList, source)
	return SystemError.success
end

function portalCtrl.sendRes(roleId, goodsId, amount)
	local roleId = tonumber(roleId)
	local goodsId = tonumber(goodsId)
	local amount = tonumber(amount)
	if not roleId or not goodsId or not amount then
		return SystemError.argument
	end
	chargeCtrl.sendGoods(roleId, {{goodsId = goodsId, amount = amount}}, logConst.portalGet)
	if amount <= 0 then
		chargeCtrl.recordActivity(roleId, amount/5000)
	end
	return SystemError.success
end

function portalCtrl.sendExchangeRes(roleId, goodsId, amount)
	local roleId = tonumber(roleId)
	local goodsId = tonumber(goodsId)
	local amount = tonumber(amount)
	if not roleId or not goodsId or not amount then
		return SystemError.argument
	end
	chargeCtrl.sendGoods(roleId, {{goodsId = goodsId, amount = amount}}, logConst.exchangeRes)
	if amount <= 0 then
		chargeCtrl.recordActivity(roleId, amount/5000)
	end
	return SystemError.success
end

function portalCtrl.sendGun(roleId, gunId, time)
	local roleId = tonumber(roleId)
	local gunId = tonumber(gunId)
	local time = tonumber(time)
	if not roleId or not gunId then
		return SystemError.argument
	end
	if time == 0 then
		time = nil
	end
	chargeCtrl.sendGun(roleId, gunId, time, logConst.portalGet)
	return SystemError.success
end 

function portalCtrl.setCatchFishSetting(type, value)
	context.sendS2S(SERVICE.CATCH_FISH, "setSetting", type, tonumber(value))
end

function portalCtrl.getAllSettings()
	local result = context.callS2S(SERVICE.CATCH_FISH, "getAllSettings")
	return SystemError.success, result
end

function portalCtrl.kickByRoleId(roleId)
	logger.Pf("portalCtrl.kickByRoleId(roleId:%s)", roleId)
	local roleId = tonumber(roleId)
	context.sendS2S(SERVICE.WATCHDOG, "kickByRoleId", roleId)
	return SystemError.success
end

function portalCtrl.kickByRoleIdList(roleIdList)
	logger.Pf("portalCtrl.kickByRoleIdList(roleIdList:%s)", dumpString(roleIdList))
	roleIdList = json.decode(roleIdList)
	for _,roleId in pairs(roleIdList) do
		context.sendS2S(SERVICE.WATCHDOG, "kickByRoleId", tonumber(roleId))
	end
	return SystemError.success
end

function portalCtrl.kickAll()
	context.sendS2S(SERVICE.WATCHDOG, "kickAllRole")
	return SystemError.success
end

function portalCtrl.stopAuthService()
	context.sendS2S(SERVICE.AUTH, "closeServer", true)
	return SystemError.success
end

function portalCtrl.startAuthService()
	context.sendS2S(SERVICE.AUTH, "closeServer", false)
	return SystemError.success
end

function portalCtrl.stopServer()
	portalCtrl.stopAuthService()
	portalCtrl.kickAll()
	context.callS2S(SERVICE.RANK, "recordCacheToDb")
	return SystemError.success
end

function portalCtrl.startServer()
	portalCtrl.startAuthService()
	return SystemError.success
end

function portalCtrl.getMobileNum(uid)
	local phoneNum = dbHelp.call("role.findMobieNum", uid)
	return SystemError.success, phoneNum
end

function portalCtrl.addRobot(nickname)
	if dbHelp.call("auth.getRoleIdByNickname", nickname) then
		return AuthError.nicknameIsExists
	end
	if not dbHelp.call("auth.getRobotByNickname", nickname) then
	    dbHelp.call("auth.addRobot", nickname)
	end
	return SystemError.success
end

function portalCtrl.setRechargeActivityStatus(status)
	local status = status and true or false
	context.callS2S(SERVICE.CHARGE, "setRechargeActivityStatus", status)
	return SystemError.success
end

--[[
	roleIds = {1024, 2047} --json格式， 接收邮件的玩家id列表
	mailData = {
		mailType = 1,      -- 1-附件, 2-无附件
		pageType = 1,	   -- 1-系统邮件, 2-奖品邮件 
		title = "test",	   -- 标题
		content = "内容",   -- 正文
		source = 1,			-- 来源
		attach = {{goodsId = 1, amount = 2,gunId = 1, time = 10}},  --附件，资源
	}
]]
function portalCtrl.sendMail(roleIds, mailData)
	local roleIds = json.decode(roleIds)
	local mailData = json.decode(mailData)
	local function toIntArr(arr)
		local tem = {}
		for _,roleId in pairs(arr) do
			tem[tonumber(roleId)] = true
		end
		local result = {}
		for roleId,_ in pairs(tem) do
			table.insert(result, roleId)
		end
		return result
	end
	if roleIds then
		roleIds = toIntArr(roleIds)
	end

	if not mailData then
		return SystemError.argument
	end

	if mailData.attach and #mailData.attach > 0 then
		mailData.mailType = 1
	else
		mailData.mailType = 2
	end

	if not roleIds or #roleIds == 0 then
		context.callS2S(SERVICE.MAIL, "sendGlobalMail", mailData)
	else
		context.callS2S(SERVICE.MAIL, "sendMailToRoles", roleIds, mailData)
	end
	return SystemError.success
end

function portalCtrl.changeRankRecordSec(recordSec)
	context.callS2S(SERVICE.RANK, "changeRecordSec", recordSec)
	return SystemError.success
end

function portalCtrl.getRoleGunIds(roleId)
	local guns = dbHelp.call("role.getAttrVal", tonumber(roleId), "guns")
	return SystemError.success, guns
end

function portalCtrl.changeActivityTime(activityId, status, sTime, eTime, round)
	logger.Infof("portalCtrl.changeActivityTime(activityId:%s, status:%s, sTime:%s, eTime:%s, round:%s)", activityId, status, sTime, eTime, round)

	local activityId = tonumber(activityId)
	local status = tonumber(status)
	local sTime = tonumber(sTime)
	local eTime = tonumber(eTime)
	return context.callS2S(SERVICE.ACTIVITY, "changeActivityTime", activityId, status, sTime, eTime, round, true)
end

function portalCtrl.changeMiscOnlineConfig()
	logger.Infof("portalCtrl.changeMiscOnlineConfig()")
	return context.callS2S(SERVICE.MISC, "changeMiscOnlineConfig")
end

function portalCtrl.saveVipAddress(roleId)
	local roleId = tonumber(roleId)
	if not roleId or roleId <= 0 then
		return SystemError.argument
	end
	local vipInfoAward = dbHelp.call("role.getAttrVal", roleId, "vipInfoAward")
	if not vipInfoAward then
		local mailData = {mailType = 1, pageType = 1, source = logConst.vipInfoGet, attach = {{goodsId = roleConst.GOLD_ID, amount = roleConst.vipAwardGold}}, title = language("超级会员"), content = language("超级会员奖励")}
		context.sendS2S(SERVICE.MAIL, "sendMail", roleId, mailData)
		dbHelp.call("role.setAttrVal", roleId, "vipInfoAward", true)
	end
	return SystemError.success
end

function portalCtrl.sealRole(roleId,time)
	local roleId = tonumber(roleId)
	local endTime = os.time() + tonumber(time)
	dbHelp.call("role.sealRole", roleId, endTime)
	context.sendS2S(SERVICE.WATCHDOG, "kickByRoleId", roleId)
	return SystemError.success
end

function portalCtrl.cannelSealRole(roleId)
	local roleId = tonumber(roleId)
	dbHelp.call("role.cannelSealRole", roleId)
	return SystemError.success
end

function portalCtrl.getRoleInfo(roleId)
	local roleId = tonumber(roleId)
	local roleInfo = dbHelp.call("auth.getRoleInfo", roleId)
	return SystemError.success, roleInfo
end

function portalCtrl.getNicknameByRoleId(roleId)
	local roleId = tonumber(roleId)
	local roleInfo = dbHelp.call("auth.getRoleInfo", roleId)
	return SystemError.success, roleInfo and roleInfo.nickname
end

function portalCtrl.getNicknameByMobileNum(mobileNum)
	local roleId = dbHelp.call("role.isMobileLocked", mobileNum)
	if not roleId then
		return SystemError.success, {}
	end
	local roleInfo = dbHelp.call("auth.getRoleInfo", roleId)
	return SystemError.success, {roleId = roleId, nickname = roleInfo.nickname, uid = roleInfo.uid}
end

function portalCtrl.sendFirstLuckyRound(roleId, leftSec)
	local roleId = tonumber(roleId)
	skynet.timeout(leftSec * 100 , function()
		context.sendS2C(roleId, M_Fund.onFirstFund)
	end)
	return SystemError.success
end

function portalCtrl.openExchangeActivity(roleId, miscCode, coupon_select)
	logger.Infof("portalCtrl.openExchangeActivity(roleId:%s, miscCode:%s, coupon_select:%s)", roleId, miscCode, coupon_select)
	local roleId = tonumber(roleId)
	return context.callAgentFunc(roleId, "sign.sign_ctrl", "open", roleId, miscCode, coupon_select)
end

function portalCtrl.openMiscOnline(roleId, miscType)
	logger.Infof("portalCtrl.openMiscOnline(roleId:%s, type:%s)", roleId, miscType)
	local roleId = tonumber(roleId)
	return context.callAgentFunc(roleId, "misc.misc_ctrl", "open", roleId, miscType)
end

function portalCtrl.addMarqueeInfo(info)
	local marqueeCtrl = require("marquee.marquee_ctrl")
	marqueeCtrl.addMarqueeInfo(info)
	return SystemError.success
end

function portalCtrl.setMarqueeInfo(info)
	local marqueeCtrl = require("marquee.marquee_ctrl")
	marqueeCtrl.setMarqueeInfo(info)
	return SystemError.success
end

function portalCtrl.delMarqueeInfo(marqueeId)
	local marqueeCtrl = require("marquee.marquee_ctrl")
	marqueeCtrl.delMarqueeInfo(marqueeId)
	return SystemError.success
end

function portalCtrl.addNotFishGold(roleId, amount)
	logger.Infof("portalCtrl.addNotFishGold(roleId:%s, amount:%s)", roleId, amount)
	local roleId = tonumber(roleId)
	local amount = tonumber(amount)
	
	-- 玩家不在线
	local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
    if not agentAdress then
		local notFishGold = dbHelp.call("role.getAttrVal", roleId, "notFishGold")
		notFishGold = notFishGold + amount
		if notFishGold < 0 then
			notFishGold = 0
		end
		dbHelp.send("role.setAttrVal", roleId, "notFishGold", notFishGold)
		return
	end
	return context.callAgentFunc(roleId, "role.role_ctrl", "addNotFishGold", roleId, amount)
end


-- 玩家协议统计
function portalCtrl.setMsgRecord(isRecord, recordInterval, roleId, number)
	isRecord = (isRecord or 0) == "1" and true or false
	logger.Pf("portalCtrl.setMsgRecord(isRecord:%s, recordInterval:%s, roleId:%s number:%s)", isRecord, recordInterval, roleId, number)
	if type(recordInterval) == "string" then 
		recordInterval = tonumber(recordInterval)
	end
	if type(roleId) == "string" then 
		roleId = tonumber(roleId)
	end
	if type(number) == "string" then 
		number = tonumber(number)
	end
	context.sendS2S(SERVICE.WATCHDOG, "setMsgRecord", isRecord, recordInterval, roleId, number)
end

-- 获取 IP 设置
function portalCtrl.getEnabledIPLimit()
	local result = context.callS2S(SERVICE.AUTH, "getEnabledIPLimit")
	return SystemError.success, result
end

-- 设置 IP 登陆限制
function portalCtrl.enabledIPLimit(enabled, login_count)
	enabled = (enabled or 0) == "1" and true or false
	if login_count and type(login_count) == "string" then 
		login_count = tonumber(login_count)
	end
	context.sendS2S(SERVICE.AUTH, "enabledIPLimit", enabled, login_count)
end

-- 获取指定 IP 登陆的玩家
function portalCtrl.getRoleListByIp(ip)
	local result = context.callS2S(SERVICE.WATCHDOG, "getRoleListByIp", ip)
	logger.Pf("portalCtrl.getRoleListByIp(ip:%s) result:%s", ip, dumpString(result))
	return SystemError.success, result
end

return portalCtrl