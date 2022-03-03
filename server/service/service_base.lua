local skynet = require("skynet")
local protobuf = require("protobuf")

local protoMap = require("proto_map")
local json = require("json")
local logger = require("log")
local clientHelper = require("common.client_helper")
local context = require("common.context")

local ServiceBase = {
	name = nil,
	modules = {},
	command = nil,
	isAgent = false,
	context = context,
}

clientHelper.ServiceBase = ServiceBase

local onlines = {}

ServiceBase.command = require("command_base")
local command = ServiceBase.command

function command.login(roleId, client, serverId)
	onlines[client] = roleId
	if command.onLogin then
		command.onLogin(roleId, client, serverId)
	end
end

function command.logout(roleId, client)
	onlines[client] = nil
	if command.onLogout then
		command.onLogout(roleId, client)
	end
end

function command.redirect(client, buffer)
	clientHelper.redirect(client, buffer)
end

function command.gc()
	collectgarbage("collect")
end

function ServiceBase.start()
	skynet.start(function()
		ServiceBase.onStart()
		if ServiceBase.name then
			skynet.send("SERVICE", "lua", "add", ServiceBase.name, skynet.self())
		end
	end)
end

function ServiceBase.onStart()
end

return ServiceBase