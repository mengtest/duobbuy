local skynet  = require("skynet")
local json    = require("json")
local logger  = require("log")
local context = require("common.context")
-- local global  = require("config.global")
local ServiceRegister = require("service_register")
local httpc = require("http.httpc")
local md5    = require("md5")

local dbHelp = require("common.db_help")

local AuthConst = require("auth.auth_const")
local LoginStatus = AuthConst.LoginStatus
local Gender = AuthConst.Gender

local RobotInfoConfig = require("config.robot_info")

local centerServerHost = skynet.getenv("centerServerHost")
local centerServerUrl = skynet.getenv("centerServerUrl")
local centerServerKey = skynet.getenv("centerServerKey")

local authCtrl = {}

local onlineWatchers = {}
local onlines = {}
local onlinesOfuid = {}
local AccountInfoIndex = {}

local logicSvcs = {}
local logicSvcIndex = 1

local CHECK_LOGIN_TIME_LEN = tonumber(skynet.getenv("checkLoginTimeLen"))
local FORBID_TIME_LEN = tonumber(skynet.getenv("forbidTimeLen"))
local MAX_LOGIN_COUNT = tonumber(skynet.getenv("enabledLoginCount"))
local enabledIPLimit = skynet.getenv("enabledIPLimit") == "1"
local whiteDevices

local function initLogicPool()
	local logicCount = skynet.getenv("logicCount")
	for i = 1, logicCount do
		logicSvcs[#logicSvcs + 1] = skynet.newservice("auth_logic_svc")
	end
end

local function getLogicSvc()
	local svc = logicSvcs[logicSvcIndex]
	logicSvcIndex = logicSvcIndex + 1
	if logicSvcIndex > #logicSvcs then
		logicSvcIndex = 1
	end
	return svc
end

function authCtrl.init()
	initLogicPool()
	ServiceRegister.init()
	authCtrl.loadWhiteDevices()
	authCtrl.initLoginIp()
	authCtrl.initNickName()
end

function authCtrl.loadWhiteDevices()
	whiteDevices = dbHelp.call("auth.getWhiteDevices")
end

local loginIpIndex
function authCtrl.initLoginIp()
	loginIpIndex = dbHelp.call("auth.getLoginIp", skynet.time() - CHECK_LOGIN_TIME_LEN)
end

function authCtrl.recordLoginIp(ip, uid, time)
	time = time or skynet.time()
	if not loginIpIndex[ip] then 
		loginIpIndex[ip] = {}
	end 
	loginIpIndex[ip][uid] = time
end

function authCtrl.getLoginIpCount(ip, startTime)
	startTime = startTime or (skynet.time() - CHECK_LOGIN_TIME_LEN)
	
	local count = 0
	local uidList = loginIpIndex[ip] or {}
	for _,v in pairs(uidList) do
		if v > startTime then 
			count = count + 1
		end
	end
	return count 
end

local NickNameIndex
function authCtrl.initNickName()
	-- 数据库昵称
	NickNameIndex = dbHelp.call("auth.getAllNickName")

	-- 机器人昵称
	for _,VO in pairs(RobotInfoConfig) do
		NickNameIndex[VO.key] = true
	end

	logger.Infof("初始化玩家昵称 数量:%s", table.nums(NickNameIndex))
	printf("初始化玩家昵称 数量:%s", table.nums(NickNameIndex))
end

function authCtrl.isNickNameExists(nickName)
	return NickNameIndex[nickName] or false
end

function authCtrl.recordNickName(nickName)
	NickNameIndex[nickName] = true
end 

function authCtrl.changeNickName(orig, curr)
	if orig == curr then 
		return SystemError.success
	end
	if NickNameIndex[curr] then 
		return AuthError.nicknameIsExists
	end
	NickNameIndex[orig] = nil
	NickNameIndex[curr] = true
	return SystemError.success
end


function authCtrl.getEnabledIPLimit()
	return {enabled = enabledIPLimit, login_count = MAX_LOGIN_COUNT}
end

function authCtrl.enabledIPLimit(enabled, login_count)
	logger.Pf("function authCtrl.enabledIPLimit(enabled:%s, login_count:%s)", enabled, login_count)
	enabledIPLimit = enabled
	MAX_LOGIN_COUNT = login_count or MAX_LOGIN_COUNT
end

function authCtrl.checkForbid(ip, role, data)
	if enabledIPLimit and (not data.imei or not whiteDevices[data.imei]) then
		local now = os.time()
		--判断是否为封禁IP
		local forbidEndTime = dbHelp.call("auth.getForbidIPEndTime", ip)
		if forbidEndTime > now then
			logger.Errorf("authCtrl.checkForbid(ip:%s, role:%s, data:%s) forbidEndTime:%s 剩余时间::%s", ip, role, dumpString(data), forbidEndTime, (forbidEndTime - now))
			return SystemError.loginExpetion
		end

		if role.loginIP then
			local endTime = dbHelp.call("auth.getForbidIPEndTime", role.loginIP)
			if endTime > now then
				logger.Errorf("authCtrl.checkForbid(ip:%s, role:%s, data:%s) endTime:%s 剩余时间:%s", ip, role, dumpString(data), endTime, (endTime - now))
				return SystemError.loginExpetion
			end
		end
		
		-- local startTime = math.max(forbidEndTime, now - CHECK_LOGIN_TIME_LEN)
		-- local count = dbHelp.call("auth.getLoginUserCountByIP", ip, startTime, MAX_LOGIN_COUNT)
		local count = authCtrl.getLoginIpCount(ip, startTime)
		if count >= MAX_LOGIN_COUNT then
			dbHelp.send("auth.setForbidIP", ip, now + FORBID_TIME_LEN)
			logger.Errorf("authCtrl.checkForbid(ip:%s, role:%s, data:%s) count:%s MAX_LOGIN_COUNT:%s", ip, role, dumpString(data), count, MAX_LOGIN_COUNT)
			return SystemError.loginExpetion
		end
	end
	return SystemError.success
end

function authCtrl.watch(handle)
	onlineWatchers[handle] = true
end

function authCtrl.castLogin(roleId, client, requestId, accountInfo)
	local online = onlines[client]
	context.callS2S(SERVICE.AGENT, "login", roleId, client, requestId, accountInfo)
	for handle in pairs(onlineWatchers) do
		context.callS2S(handle, "login", roleId, client)
	end
end

function authCtrl.castLogout(client)
	local online = onlines[client]
	if not online then
		return
	end
	AccountInfoIndex[online.uid] = nil

	context.callS2S(SERVICE.AGENT, "logout", online.roleId, client)
	logger.Infof("auth.castLogout, roleId[%s]", online.roleId)
	onlines[client] = nil
	if online == onlinesOfuid[online.uid] then
		onlinesOfuid[online.uid] = nil
	end
	for handle in pairs(onlineWatchers) do
		context.callS2S(handle, "logout", online.roleId, client)
	end

	context.callS2S(SERVICE.WATCHDOG, "checkKickAllRole")
end

function authCtrl.closeServer(isClose)
	ServiceRegister.closeServer(isClose)
end

function authCtrl.notifySerivceStatus(serivceName)
	ServiceRegister.registerSerivce(serivceName)
end

function authCtrl.login(client, data, requestId)
	if not ServiceRegister.isOpenServer() then
		return SystemError.ServerMaintenance
	end
	logger.Infof("auth.login, data[%s] fd = [%s]", json.encode(data), client)
	
	local online = onlines[client]
	if online then
		if online.status ~= LoginStatus.LOGINING then
			return SystemError.logined
		end
		return SystemError.busy
	end

	--验证登录信息
	local svc = getLogicSvc()
	local ec, role, accountInfo = context.callS2S(svc, "login", data)
	if ec ~= SystemError.success then
		return ec
	end
	
	local ip = context.callS2S(SERVICE.WATCHDOG, "getClientIp", client)
	ip = string.split(ip, ":")[1]

	--验证同一ip是否登录过多
	local ec = authCtrl.checkForbid(ip, role, data)
	if ec ~= SystemError.success then
		return ec
	end

	--验证该账号是否已经登录了，有则踢下线
	local other = onlinesOfuid[data.uid]
	if other then
		context.callS2S(SERVICE.WATCHDOG, "kick", other.client)
	end
	online =  {client = client, uid = data.uid, status = LoginStatus.LOGINING}
	onlines[client] = online

	online.status = LoginStatus.LOGINED
	onlinesOfuid[data.uid] = online
	AccountInfoIndex[data.uid] = accountInfo	

	-- 记录账号登陆的 IP
	authCtrl.recordLoginIp(ip, data.uid)	

	local roleId = role.roleId
	if not roleId then
		context.sendS2S(SERVICE.WATCHDOG, "loginFailure", client)
		return ec, {}
	end
	online.roleId = roleId
	online.status = LoginStatus.ACTIVED
   	authCtrl.castLogin(roleId, client, requestId, accountInfo)

   	dbHelp.send("role.setAttrVal", roleId, "loginIP", ip)

   return SystemError.forward
end

function authCtrl.createRole(client, data, requestId)
	logger.Debugf("auth.createRole, data[%s]", json.encode(data))
	local online = onlines[client]
	if online == nil or online.status ~= LoginStatus.LOGINED then
		logger.Errorf("online status is invalid, client[0x%x]", client)
		return SystemError.notLogin
	end

	if online.roleId then
		return AuthError.hasRole
	end

	local ip = context.callS2S(SERVICE.WATCHDOG, "getClientIp", client)
	ip = string.split(ip, ":")[1]

	data.uid = online.uid
	data.ip = ip

	-- 验证昵称是否重复
	if not data.nickname or authCtrl.isNickNameExists(data.nickname) then
		return AuthError.nicknameIsExists
	end

	local svc = getLogicSvc()
	local ec, roleId = context.callS2S(svc, "create", data)
	if ec ~= SystemError.success then
		return ec
	end
	
	-- 记录使用的昵称
	authCtrl.recordNickName(data.nickname)

	if not roleId then
		assert(false, tableToString(data))
	end
	online.roleId = roleId
	online.status = LoginStatus.ACTIVED

	authCtrl.castLogin(roleId, client, requestId, AccountInfoIndex[data.uid])

	return SystemError.forward
end

return authCtrl

