--[[
    该文件必须在agent_mgr服务上执行，限于更新agent
    首先通过调试控制台的list命令获取agent_mgr服务地址
    然后执行以下命令:
    telnet 127.0.0.1 5054
    inject :04000009 ./logic/update/agent_updater.lua
    :04000009为agent_mgr服务地址
]]
local codecache = require("skynet.codecache")
local hotfix = require("common.hotfix")
local context = require("common.context")
local configUpdater = require("update.config_updater")



local Updater = {}

--清理代码缓存，如果只是修复内存状态，没有更新代码，则不要调用
codecache.clear()

local command = _P.lua.command

local agents = command.getAgents()

--更新配置
-- local configs = {
--     "recharge_disk_config"
-- }
-- local cachedConfigs = command.getConfigs()
-- for _, value in ipairs(configs) do
-- 	package.loaded["config." .. value] = nil
-- end
-- configUpdater.update({}, cachedConfigs, configs)


--更新agent
local fixFile = "./logic/update/agent_fix.lua" --更新agent的代码逻辑
local chunk = hotfix.getChunk(fixFile)
local updatedAgents = 0
local agents = command.getAgents()
for _, svc in pairs(agents) do
    local output = context.callS2S(svc, "run", chunk, fixFile)
    print(table.concat( output, ", "))
    updatedAgents = updatedAgents + 1
    if updatedAgents > 100 then
    	break
    end
end
agents = command.getAgentPool()
for _, svc in pairs(agents) do
    local output = context.callS2S(svc, "run", chunk, fixFile)
    print(table.concat( output, ", "))
    updatedAgents = updatedAgents + 1
end
print("updatedAgents", updatedAgents)