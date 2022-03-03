local skynet  = require("skynet")
local json	   = require("json")
local dbHelp   = require("common.db_help")
local context = require("common.context")
local resCtrl  = require("common.res_operate")
local roleCtrl = require("role.role_ctrl")
local roleConst = require("role.role_const")
local mobileConst = require("mobile.mobile_const")
local portalConst = require("portal.portal_const")
local LogConst  = require("game.log_const")
local dbHelp = require("common.db_help")
local logger     = require("log")
local KEY = skynet.getenv("centerServerKey")
local md5    	= require("md5")

local mobileCtrl = {}

function mobileCtrl.needLockMobile(roleId)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if roleInfo.mobileNum then
		return false
	end

	local accountInfo = roleCtrl.getAccountInfo(roleId)
	if accountInfo.BindStatus then 
		logger.Debugf("accountInfo:"..dumpString(accountInfo))
		return true
	end
	return false
end 

function mobileCtrl.sendActiveCode(roleId, mobile)
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if roleInfo.mobileNum then
		logger.Errorf("mobileCtrl.sendActiveCode(roleId:%s, mobile:%s)", roleId, mobile)
		return MobileError.hadExist
	end
	local flag = dbHelp.call("role.isMobileLocked", mobile)
	if flag then
		logger.Errorf("mobileCtrl.sendActiveCode(roleId:%s, mobile:%s)", roleId, mobile)
		return MobileError.hadExist
	end
	local data = {
		method = "sendActiveCode",
		mobile = mobile,
		roleId = roleId,
	}
	local success, result = mobileCtrl.centerRequest(data)
	if not success then
		logger.Errorf("mobileCtrl.sendActiveCode(roleId:%s, mobile:%s) result:%s", roleId, mobile, dumpString(result))
		-- return MobileError.httpError
		local err = portalConst.HttpError(result.errorCode, MobileError.httpError)
		-- print("err:"..err)
		return err
	end
	return SystemError.success
end

function mobileCtrl.checkActiveCode(roleId, codeNum, password)
	-- 未绑定过手机
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	if roleInfo.mobileNum then
		logger.Errorf("mobileCtrl.checkActiveCode(roleId:%s, codeNum:%s, password:%s)", roleId, codeNum, password)
		return MobileError.hadExist
	end

	local data = {
		method = "checkActiveCode",
		codeNum = codeNum,
		roleId = roleId,
	}
	local success, result = mobileCtrl.centerRequest(data)
	if not success then
		logger.Errorf("mobileCtrl.checkActiveCode(roleId:%s, codeNum:%s, password:%s) result:%s", roleId, codeNum, password, dumpString(result))
		if result.errorCode then
			return MobileError.notMatch
		else
			return MobileError.httpError
		end
	end

	-- 绑定手机号
	assert(result.data, "mobileCtrl.checkActiveCode result.data null")
	roleCtrl.lockMobile(roleId, result.data)
	resCtrl.send(roleId, roleConst.GOLD_ID, mobileConst.awardNum, LogConst.mobileLockGet)

	-- 修改密码
	if password and password ~= "" then
		local pwdData = {
			method = "setNewPwd",
			roleId = roleId,
			newPwd = password,
			originStr = md5.sumhexa(roleId..KEY..password)
		}
		local success, result = mobileCtrl.centerRequest(pwdData)
		if not success then
			logger.Errorf("mobileCtrl.checkActiveCode(roleId:%s, codeNum:%s, password:%s) result:%s", roleId, codeNum, password, dumpString(result))
			return MobileError.setNewPwdErr
		end		
	end
	return SystemError.success
end

function mobileCtrl.centerRequest(data)
	local result = context.callS2S(SERVICE.RECORD, "callDataToCenter", data)
	result = json.decode(result)
	local success = false
	if result and result.errorCode == 0 then
		success = true
	end
	return success, result
end

return mobileCtrl