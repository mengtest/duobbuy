local conf = require("sharedata.corelib")

local configDb = {}
local configKeys = {}

setmetatable(configDb, {
    __index = function(t, k)
        local value = configKeys[k]
        if value == nil  then
            -- return require("config." .. k) 
            return nil 
        end
        if value[2] then
            return value[2]
        end
        local obj = conf.box(value[1])
        value[2] = obj
        return obj
    end
})

function configDb.init(configs)
    for k, p in pairs(configs) do
        configKeys[k] = {p}
    end
end

function configDb.update(configs)
    for k, p in pairs(configs) do
        local value = configKeys[k]
        if value then
            if value[2] then
                conf.update(value[2], p)
            end
            value[1] = p
        else
            configKeys[k] = {p}
        end
    end
end

function configDb.getConfig(configName)
    return configKeys[configName]
end
function configDb.getAllConfigs()
    return configKeys
end
return configDb


