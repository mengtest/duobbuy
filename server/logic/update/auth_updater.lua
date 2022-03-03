--[[
	连接debug端口 telnet 127.0.0.1 5051
    inject :0100000b ./logic/update/auth_updater.lua
]]

local codecache = require("skynet.codecache")
local hotfix = require("common.hotfix")
local context = require("common.context")
local configUpdater = require("update.config_updater")

local Updater = {}

--清理代码缓存，如果只是修复内存状态，没有更新代码，则不要调用
--codecache.clear()

local command = _P.lua.command

--更新配置
-- local configs = {
--     "goods"
-- }
-- local cachedConfigs = command.getConfigs()
-- configUpdater.update(agents, cachedConfigs, configs)

local authCtrl = hotfix.getupvalue(command.watch, "authCtrl")
local getLogicSvc = hotfix.getupvalue(authCtrl.login, "getLogicSvc")
local logicSvcs = hotfix.getupvalue(getLogicSvc, "logicSvcs")

local fixFile = "./logic/update/auth_logic_fix.lua" 
local chunk = hotfix.getChunk(fixFile)
print("chunk", #chunk)
for _, svc in pairs(logicSvcs) do
	 local output = context.callS2S(svc, "run", chunk, fixFile)
	 print(table.concat(output))
end
