-- telnet 127.0.0.1 5056
-- inject :06000011 ./logic/update/red_money_updater.lua


local codecache = require("skynet.codecache")
local hotfix = require("common.hotfix")
local context = require("common.context")
local configUpdater = require("update.config_updater")

local Updater = {}

--清理代码缓存，如果只是修复内存状态，没有更新代码，则不要调用
--codecache.clear()

local command = _P.lua.command

-- local authCtrl = hotfix.getupvalue(command.watch, "authCtrl")
-- local getLogicSvc = hotfix.getupvalue(authCtrl.login, "getLogicSvc")
-- local logicSvcs = hotfix.getupvalue(getLogicSvc, "logicSvcs")

local fixFile = "./logic/update/red_money_fix.lua" 
local chunk = hotfix.getChunk(fixFile)
local svc = 0x6000011
local output = context.callS2S(svc, "run", chunk, fixFile)
-- print("chunk", #chunk)
-- for _, svc in pairs(logicSvcs) do
-- 	dump(svc)
-- 	 local output = context.callS2S(0x6000011, "run", chunk, fixFile)
-- 	 print(table.concat(output))
-- end
