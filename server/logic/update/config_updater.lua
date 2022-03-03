local hotfix = require("common.hotfix")
local context = require("common.context")
local conf = require("sharedata.corelib")
local pathprefix = "config."
local new = function(path) return conf.host.new(require(pathprefix .. path)) end
local markdirty = conf.host.markdirty

local ConfigUpdater = {}

--[[
    更新配置
    @param agents 要更新的agent对象集
    @param cachedConfigs 已经换成的配置集
    @param configs 要更新的配置列表
]]
function ConfigUpdater.update(agents, cachedConfigs, configs)
    local updated = {}
    for _, value in pairs(configs) do
        local oldValue = cachedConfigs[value]
        if oldValue then
            markdirty(oldValue)
        end
        package.loaded[pathprefix .. value] = nil
        local newValue = new(value)
        cachedConfigs[value] = newValue
        updated[value] = newValue
    end
    
    for _, agent in pairs(agents) do
        context.sendS2S(agent, "updateConfigs", updated)
    end
end

return ConfigUpdater