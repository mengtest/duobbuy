local portalConst = {}

portalConst.errors = {}
local function add(error)
	assert(portalConst.errors[error.code] == nil, string.format("had the same error code[%x], msg[%s]", error.code, error.message))
	portalConst.errors[error.code] = error
	return error.code
end

local MobileError = {
	forbidLogin			  = add{code = 54, message = "您的账号存在异常，请联系客服", sysError = SystemError.roleIsSeal},
	sendCodeTooFrequently = add{code = 1010, message = "获取验证码过于频繁", sysError = RoleError.sendCodeTooFrequently},
}

portalConst.HttpError = function (errID, default)
	local error = portalConst.errors[errID]
	if error then 
		return error.sysError
	end 
	return default or MobileError.httpError
end 


return portalConst