local skynet = require("skynet")
local json = require("json")
local logger = require("log")
local md5    = require("md5")
local context = require("common.context")
local dbHelp = require("common.db_help")
local wordFilter = require("common.word_filter")

local global = require("config.global")
local RobotInfoConfig = require("config.robot_info")

local AuthConst = require("auth.auth_const")
local Gender = AuthConst.Gender
local serverId = skynet.getenv("serverId")

local authLogicSvc = require("command_base")
local portalConst = require("portal.portal_const")

local centerServerKey = skynet.getenv("centerServerKey")
local wordFilterPath = skynet.getenv("wordFilterPath")

function authLogicSvc.init()
	wordFilter.init(wordFilterPath)
end

function authLogicSvc.getAccountInfo(data)
	local httpData = {
		method = "getAccountInfo",
		uid = data.uid,
		token = data.token,
		imei = data.imei,
	}
	local result = context.callS2S(SERVICE.RECORD, "callDataToCenter", httpData)
	if not result then
		-- logger.Errorf("httpData:%s result:%s", dumpString(httpData), dumpString(result))
		-- return AuthError.tokenIsInvalid
	end
	
	result = json.decode(result)
	if not result or result.errorCode ~= 0 then
		-- logger.Errorf("httpData:%s result:%s", dumpString(httpData), dumpString(result))
		-- return portalConst.HttpError(result.errorCode, AuthError.tokenIsInvalid)
	end
	-- return SystemError.success, result.data
	return SystemError.success
end 

function authLogicSvc.login(data)
	if data.signTime + global.AUTH_TOKEN_TIMEOUT < os.time() then
		return AuthError.tokenIsTimeout
	end

	local sum = md5.sumhexa(data.uid .. data.signTime .. centerServerKey)
	if sum ~= data.token then
		-- logger.Errorf("authLogicSvc.login(data) sum:%s data:%s", sum, dumpString(data))
		-- return AuthError.tokenIsInvalid
	end
	
	-- 获得平台账号状态
	local ret, accountInfo = authLogicSvc.getAccountInfo(data)
	if ret ~= SystemError.success then 
		return ret
	end 

	local role = dbHelp.call("auth.getRole", data.uid)

	-- 验证是否被封号
	if role.roleId then
		local sealRecord = dbHelp.call("role.checkIsSeal", role.roleId)
		if sealRecord and sealRecord.endTime > os.time() then
			return SystemError.roleIsSeal
		end
	end
	return SystemError.success, role, accountInfo
end

function authLogicSvc.create(data)
	-- local info = roleCreateConfig[data.index]
	-- if info == nil then
	-- 	return SystemError.argument
	-- end

	-- 性别验证
	-- if data.gender ~= Gender.MALE
	-- 	and data.gender ~= Gender.FEMALE then
	-- 	return SystemError.argument
	-- end

	-- if not data.nickname then
	-- 	return AuthError.nicknameIsExists
	-- end
	
	-- -- 是否与机器人名字重复
	-- if RobotInfoConfig[data.nickname] then
	-- 	return AuthError.nicknameIsExists
	-- end

	-- local roleId = dbHelp.call("auth.getRoleIdByNickname", data.nickname)
	-- local robotId = dbHelp.call("auth.getRobotByNickname", data.nickname)
    -- if roleId or robotId then
    --     return AuthError.nicknameIsExists
    -- end

    if not wordFilter.isValid(data.nickname) then
    	return AuthError.nicknameIsInvalid
    end

	if not data.imei then
		return AuthError.imeiIsInvalid
	end

	local roleId = dbHelp.call("auth.createRole", data)
	local recordCreateRole = {roleId = roleId, accounts = data.uid, regTime = os.date("%Y-%m-%d %H:%M:%S"), nickName = data.nickname, roleLevel = 1, serverId = serverId, vipLevel = 0, channelId = data.channelId, pid = data.pid, ip = data.ip, imei = data.imei}
	logger.Infof("authLogicSvc.create data:%s", dumpString(recordCreateRole))
	context.sendS2S(SERVICE.RECORD, "recordCreateRole", recordCreateRole)
	return SystemError.success, roleId
end

skynet.start(function()
	authLogicSvc.init()
end)