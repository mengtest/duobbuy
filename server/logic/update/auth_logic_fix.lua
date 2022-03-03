-- telnet 127.0.0.1 5051
-- inject :0100000c ./logic/update/auth_logic_fix.lua
-- inject :0100000d ./logic/update/auth_logic_fix.lua
-- inject :0100000e ./logic/update/auth_logic_fix.lua
-- inject :0100000f ./logic/update/auth_logic_fix.lua

local hotfix = require("common.hotfix")
local context = require("common.context")

local command =  require("command_base")

local global = require("config.global")
local dbHelp = require("common.db_help")
local md5    = require("md5")
local skynet = require("skynet")
local json = require("json")

local centerServerKey = skynet.getenv("centerServerKey")

local authLogicSvc = command

function authLogicSvc.login(data)
	if data.signTime + global.AUTH_TOKEN_TIMEOUT < os.time() then
		return AuthError.tokenIsTimeout
	end

	local sum = md5.sumhexa(data.uid .. data.signTime .. centerServerKey)
	if sum ~= data.token then
		return AuthError.tokenIsInvalid
	end
	
	local data = {
		method = "checkToken",
		uid = data.uid,
		token = data.token
	}
	local result = context.callS2S(SERVICE.RECORD, "callDataToCenter", data)
	if not result then
		return AuthError.tokenIsInvalid
	end
	result = json.decode(result)
	if not result or result.errorCode ~= 0 then
		return AuthError.tokenIsInvalid
	end

	local role = dbHelp.call("auth.getRole", data.uid)

	--验证是否被封号
	if role.roleId then
		local sealRecord = dbHelp.call("role.checkIsSeal", role.roleId)
		if sealRecord and sealRecord.endTime > os.time() then
			return SystemError.roleIsSeal
		end
	end

	return SystemError.success, role
end
print("ok--------------")