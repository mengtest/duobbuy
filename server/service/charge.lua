local skynet  	= require("skynet")
local logger  	= require("log")
local context 	= require("common.context")
local charge    = require("service_base")
local md5    	= require("md5")
local json 		= require("json")
local dbHelp 	= require("common.db_help")
local logConst  = require("game.log_const")
local shopConfig = require("config.shop")
local roleConst = require("role.role_const")
local chargeCtrl = require("charge.charge_ctrl")

local gameServerKey = skynet.getenv("gameServerKey")
assert(gameServerKey and gameServerKey ~= "")

local command = charge.command

local function getSign(roleId, shopItemIndex)
	local signString = "roleId="..roleId.."&itemId="..shopItemIndex.."&key="..gameServerKey
	return md5.sumhexa(signString)
end

local orderList = {}

-- 签名验证`
local function checkSign(roleId, shopItemIndex, sign)
	return getSign(roleId, shopItemIndex) == sign
end

-- 充值记录
local function logChargeInfo(roleId, logInfo)
	--TODO
end

-- 充值逻辑
local function buyItem(roleId, shopItemIndex, sign)
	local logInfo = {
		roleId = roleId,
		shopItemIndex = shopItemIndex,
		sign = sign,
	}
	local isIllegal = checkSign(roleId, shopItemIndex, sign)
	if not isIllegal then return SystemError.argument, logInfo end
	local roleId = tonumber(roleId)
	local shopItemIndex = tonumber(shopItemIndex)
	local shopItemInfo = shopConfig[shopItemIndex]
	if not shopItemInfo then
		return ChargeError.shopIndexError, logInfo
	end
	logInfo.buyPrice = shopItemInfo.price

	local ec, chargeInfo = chargeCtrl.chargeMoney(roleId, shopItemIndex)
	if chargeInfo then
		table.merge(logInfo, chargeInfo)
	end
	
	return ec, logInfo
end

-- 模拟充值
local function deBugBuyItem(roleId, shopItemIndex)
	local logInfo = {
		roleId = roleId,
		shopItemIndex = shopItemIndex,
		debug = true,
	}

	local roleId = tonumber(roleId)
	local shopItemIndex = tonumber(shopItemIndex)
	local shopItemInfo = shopConfig[shopItemIndex]
	if not shopItemInfo then
		return ChargeError.shopIndexError, logInfo
	end
	logInfo.buyPrice = shopItemInfo.price

	local ec, chargeInfo = chargeCtrl.chargeMoney(roleId, shopItemIndex)
	if chargeInfo then
		table.merge(logInfo, chargeInfo)
	end

	return ec, logInfo
end

function command.buyItem(roleId, shopItemIndex, sign, orderNum)
	if not orderNum or orderList[orderNum] then
		return
	end
	
	local ok, ec, logInfo = pcall(buyItem, roleId, shopItemIndex, sign)
	if ok then
		logInfo.errorCode = ec
		logInfo.errorMsg = errmsg(ec)
		logInfo.chargeTime = os.time()
		if ec == SystemError.success then
			logChargeInfo(roleId, logInfo)
			orderList[orderNum] = true
		else
			orderList[orderNum] = nil
		end
	else
		orderList[orderNum] = nil
		skynet.error(ec)
	end
	
	return ec
end

function command.deBugBuyItem(roleId, shopItemIndex)
	local ok, ec, logInfo = pcall(deBugBuyItem, roleId, shopItemIndex)
	if ok then
		logInfo.errorCode = ec
		logInfo.errorMsg = errmsg(ec)
		logInfo.chargeTime = os.time()
		if ec == SystemError.success then
			logChargeInfo(roleId, logInfo)
		end
	else
		skynet.error(ec)
	end
	return ec
end

function command.getTotalPriceByTime(roleId, sTime, eTime)
	return chargeCtrl.getTotalPriceByTime(roleId, sTime, eTime)
end

function command.isUseJoinType(roleId, shopItemIndex)
	return chargeCtrl.isUseJoinType(roleId, shopItemIndex)
end

function command.getUseJoinTypes(roleId, goldIds, giftIds, bagIds)
	local goldStatus, giftStatus, bagStatus = {}, {}, {}
	for _,shopItemIndex in pairs(goldIds) do
		local status = chargeCtrl.isUseJoinType(roleId, shopItemIndex)
		goldStatus[#goldStatus+1] = {
			shopIndex = shopItemIndex,
			status = status
		}
	end
	for _,shopItemIndex in pairs(giftIds) do
		local status = chargeCtrl.isUseJoinType(roleId, shopItemIndex)
		giftStatus[#giftStatus+1] = {
			shopIndex = shopItemIndex,
			status = status
		}
	end
	for _,shopItemIndex in pairs(bagIds) do
		local status = chargeCtrl.isUserJoinBag(roleId, shopItemIndex)
		bagStatus[#bagStatus+1] = {
			shopIndex = shopItemIndex,
			status = status
		}
	end
	return goldStatus, giftStatus, bagStatus
end

function command.isUserJoinBag(roleId, shopItemIndex)
	return chargeCtrl.isUserJoinBag(roleId, shopItemIndex)
end

function command.setRechargeActivityStatus(status)
	chargeCtrl.setRechargeActivityStatus(status)
end

function command.openExchangeActivity(roleId, miscCode)
	chargeCtrl.openExchangeActivity(roleId, miscCode)
end

-- 启动进程
function charge.onStart()
	skynet.register(SERVICE.CHARGE)
	print("charge server start")
end

charge.start()
