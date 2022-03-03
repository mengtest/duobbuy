local skynet = require("skynet")
local onlineAwardCtrl = {}
local context = require("common.context")
local roleCtrl = require("role.role_ctrl")
local resOp = require("common.res_operate")
local dbHelp = require("common.db_help")

local configDb = require("config.config_db")
local onlineAwardConf = configDb.online_award

local logConst = require("game.log_const")
local roleConst = require("role.role_const")

local onlineInfo

local function checkAndResetInfo(roleId, isLogin)
	local now = os.time()
	local updateDate = os.date("*t", onlineInfo.updateTime)
	local nowDate = os.date("*t", now)
	if nowDate.year ~= updateDate.year
		or nowDate.month ~= updateDate.month
		or nowDate.day ~= updateDate.day then
		onlineInfo.updateTime = now
		onlineInfo.gotTypes = {}
		if isLogin then
			onlineInfo.onlineTimeLen = 0
		else
			onlineInfo.onlineTimeLen = now - os.time({year=nowDate.year, month=nowDate.month, day=nowDate.day, hour = 0})
		end
		dbHelp.send("onlineAward.updateOnlineInfo", roleId, onlineInfo)
		return true
	end
end

function onlineAwardCtrl.getInfo(roleId)
	checkAndResetInfo(roleId)

	local info = {}
	info.onlineTimeLen = onlineInfo.onlineTimeLen + os.time() - onlineInfo.updateTime
	info.gotTypes = onlineInfo.gotTypes
	return SystemError.success, info
end

function onlineAwardCtrl.receiveAward(roleId, awardId)
	local conf = onlineAwardConf[awardId]
	if not conf then
		return SystemError.argument
	end

	checkAndResetInfo(roleId)

	local now = os.time()
	local onlineTimeLen = onlineInfo.onlineTimeLen + now - onlineInfo.updateTime
	if onlineTimeLen < conf.time then
		return OnlineError.cannotGet
	end
	
	for _, id in ipairs(onlineInfo.gotTypes) do
		if id == awardId then
			return OnlineError.hasGot
		end
	end

	onlineInfo.gotTypes[#onlineInfo.gotTypes + 1] = awardId
	onlineInfo.onlineTimeLen = 0
	onlineInfo.updateTime = now

	dbHelp.send("onlineAward.updateOnlineInfo", roleId, onlineInfo)
	resOp.send(roleId, conf.award.goodsId, conf.award.amount, logConst.onlineAwardGet)

	return SystemError.success, {onlineTimeLen = onlineInfo.onlineTimeLen, gotTypes = onlineInfo.gotTypes}
end

function onlineAwardCtrl.onLogin(roleId)
	onlineInfo = dbHelp.call("onlineAward.getOnlineInfo", roleId)
	if not onlineInfo then
		onlineInfo = {}
		onlineInfo.gotTypes = {}
		onlineInfo.updateTime = os.time()
		onlineInfo.onlineTimeLen = 0
	end
	if not checkAndResetInfo(roleId, true) then
		onlineInfo.updateTime = os.time()
	end
end

function onlineAwardCtrl.onLogout(roleId)
	if not onlineInfo then
		return
	end
	if not checkAndResetInfo(roleId) then
		local now = os.time()
		onlineInfo.onlineTimeLen = onlineInfo.onlineTimeLen + now - onlineInfo.updateTime
		onlineInfo.updateTime = now
		dbHelp.send("onlineAward.updateOnlineInfo", roleId, onlineInfo)
	end
end

return onlineAwardCtrl