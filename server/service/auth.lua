local skynet = require("skynet")
local harbor = require("skynet.harbor")
local json = require("json")
local logger = require("log")
local context = require("common.context")
local authCtrl = require("auth.auth_ctrl")

local authSvc = require("service_base")

local watchdogs = {}

local command = authSvc.command

function command.watch(handle)
	authCtrl.watch(handle)
end

function command.addAgentServer(address)
	authCtrl.addAgentServer(address)
end

function command.castLogout(client)
	authCtrl.castLogout(client)
end

function command.closeServer(isClose)
	authCtrl.closeServer(isClose)
end

-- 同步服务之间的状态
function command.notifySerivceStatus(serivceName)
	authCtrl.notifySerivceStatus(serivceName)
end


function command.getEnabledIPLimit()
	return authCtrl.getEnabledIPLimit()
end

-- 设置 IP 登陆限制
function command.enabledIPLimit(enabled, login_count)
	authCtrl.enabledIPLimit(enabled, login_count)
end

-- 更改昵称
function command.changeNickName(orig, curr)
	return authCtrl.changeNickName(orig, curr)
end

function authSvc.onStart()
	skynet.register(SERVICE.AUTH)
	authCtrl.init()
	print("auth server start")
end

authSvc.modules.auth = require("auth.auth_impl")
authSvc.start()