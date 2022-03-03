--[[
    该文件必须在agent_mgr服务上执行，限于更新agent
    首先通过调试控制台的list命令获取agent_mgr服务地址
    然后执行以下命令:
    连接debug端口 telnet 127.0.0.1 5055
    inject :05000009 ./logic/update/catch_fish_updater.lua
]]
local codecache = require("skynet.codecache")
local hotfix = require("common.hotfix")
local context = require("common.context")
local configUpdater = require("update.config_updater")

local Updater = {}


print("cathc fish updater")
--清理代码缓存，如果只是修复内存状态，没有更新代码，则不要调用
--codecache.clear()

local command = _P.lua.command

--更新配置
-- local configs = {
--     "goods"
-- }
-- local cachedConfigs = command.getConfigs()
-- configUpdater.update(agents, cachedConfigs, configs)

--开启或者关闭新手保护
-- print("start set protect")
-- command.setSetting("protect", false)
-- print("end set protect")

-- local awardPoolValue = hotfix.getupvalue(command.updateAwardPool, "awardPoolValue")
-- command.updateAwardPool(-awardPoolValue / 0.92)
-- local awardPoolValue = hotfix.getupvalue(command.updateAwardPool, "awardPoolValue")
-- print(awardPoolValue)

local svcs = hotfix.getupvalue(command.setSetting, "svcs")
print("svcs", svcs)
-- local vipSvc = hotfix.getupvalue(command.setSetting, "vipSvc")
-- print("vipSvc", vipSvc)

local fixFile = "./logic/update/catch_fish_svc_fix.lua" 
local chunk = hotfix.getChunk(fixFile)
print("chunk", #chunk)
for _, svc in pairs(svcs) do
	 local output = context.callS2S(svc.svc, "run", chunk, fixFile)
	 print(table.concat(output))
end
-- local output = context.callS2S(vipSvc.svc, "run", chunk, fixFile)
-- print(table.concat(output))

-- local arenaSvc = hotfix.getupvalue(command.getArenaList, "arenaSvc")
-- local output = context.callS2S(arenaSvc.svc, "run", chunk, fixFile)
-- print(table.concat(output))
--更新虚拟玩家数
-- local VIRTUAL_PLAYER_COUNT = hotfix.getupvalue(command.leave, "VIRTUAL_PLAYER_COUNT")
