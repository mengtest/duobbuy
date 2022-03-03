local AuthConst = {}

local Gender = {
	MALE = 1,		--男
	FEMALE = 2,		--女
}
AuthConst.Gender = Gender

local LoginStatus ={
	LOGINING = 1, 		-- 登陆中
	LOGINED = 2,  		-- 登陆了
	CREATEING_ROLE = 3, 	-- 生成角色
	ACTIVED = 4,   		-- 登陆成功创建成功使用中
}
AuthConst.LoginStatus = LoginStatus

return AuthConst