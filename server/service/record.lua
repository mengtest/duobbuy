local skynet  	= require("skynet")
local logger  	= require("log")
local json 		= require("json")
local md5    	= require("md5")
local context 	= require("common.context")
local dbHelp    = require("common.db_help")
local httpc 	= require("http.httpc")
local record    = require("service_base")

local command 	= record.command

local centerServerHost = skynet.getenv("centerServerHost")
local centerServerUrl = skynet.getenv("centerServerUrl")
local centerServerKey = skynet.getenv("centerServerKey")
local refreshTime = skynet.getenv("refreshTime")
local serverId = skynet.getenv("serverId")
local pid = 0


local function sendDataToCenter(host, url, data)
	data.serverId = serverId
    local ok, msg = pcall(httpc.post, host, url, data)
    if not ok then
        skynet.error(msg)
    end
end

local function callDataToCenter(host, url, data)
	data.serverId = serverId
    local ok, msg, body = pcall(httpc.post, host, url, data)
    if not ok then
        skynet.error(msg)
    end
    if msg ~= 200 then
		return
	end
    return body
end

local function getSign(pid, method)
	return md5.sumhexa(pid .. method .. centerServerKey)
end 

function command.sendDataToCenter(postData, host, url)
	local host = host or centerServerHost
	local url = url or centerServerUrl
	postData.pid = postData.pid or pid
	postData.sign = getSign(postData.pid, postData.method)
	sendDataToCenter(centerServerHost, centerServerUrl, postData)
end

function command.callDataToCenter(postData, host, url)
	local host = host or centerServerHost
	local url = url or centerServerUrl
	postData.pid = postData.pid or pid
	postData.sign = getSign(postData.pid, postData.method)
	return callDataToCenter(centerServerHost, centerServerUrl, postData)
end


-- 创建信息
function command.recordCreateRole(userInfo)
	userInfo.method = "roleInfoLog"
	userInfo.pid = userInfo.pid or pid
	userInfo.sign = getSign(userInfo.pid, "roleInfoLog")
	sendDataToCenter(centerServerHost, centerServerUrl, userInfo)
end

-- 用户退出时记录在线时长
function command.recordUpdateUserLoginInfo(userInfo)
	userInfo.method = "updateLoginLog"
	userInfo.pid = userInfo.pid or pid
	userInfo.sign = getSign(userInfo.pid, "updateLoginLog")
	sendDataToCenter(centerServerHost, centerServerUrl, userInfo)
end

-- 兑换活动，发送 Q 币
function command.addCouponOrderInfo(roleId, couponSelect)
	if not roleId or not couponSelect then return end
	local info = {}
	info.method = "addCouponOrderInfo"
	info.sign = getSign(pid, "addCouponOrderInfo")
	info.roleId = roleId
	info.couponSelect = couponSelect
	info.originStr = md5.sumhexa(couponSelect .. roleId .. centerServerKey)
	sendDataToCenter(centerServerHost, centerServerUrl, info)
end

-- 兑换任务完成
function command.miscOnlineComplete(roleId, type, amount)
	local info = {}
	info.method = "miscOnlineComplete"
	info.sign = getSign(pid, "miscOnlineComplete")
	info.roleId = roleId
	info.type = type
	info.amount = amount
	info.originStr = md5.sumhexa(roleId .. type .. amount .. centerServerKey)
	logger.Infof("command.miscOnlineComplete(roleId, type, amount) info:%s", dumpString(info))
	sendDataToCenter(centerServerHost, centerServerUrl, info)
end

-- 在线记录
function command.recordOnlineNum(host, url, interval)
	local host = host or centerServerHost
	local url = url or centerServerUrl
	local interval = interval or refreshTime
	skynet.timeout(interval * 100, function() command.recordOnlineNum(host, url, interval) end)
	local recordNum = context.callS2S(SERVICE.WATCHDOG, "getOnlineNum")
	local postData = {
		method = "onlineInfoLog",
		sign = getSign(pid, "onlineInfoLog"),
		statTime = os.date("%Y-%m-%d %H:%M:%S"),
		pid = pid,
		onlineNum = recordNum,
	}
	sendDataToCenter(host, url, postData)
end


-- 启动进程
function record.onStart()
	skynet.register(SERVICE.RECORD)
	if refreshTime then
		command.recordOnlineNum()
	end
	print("record server start")
end

record.start()