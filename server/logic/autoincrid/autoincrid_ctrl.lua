------ 不得直接通过这个ctrl访问
------ 获取自增id的方式 context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", keytableName)
local skynet = require("skynet")
local json   = require("json")
local dbHelp        =   require("common.db_help")
--local global = require("config.global")
local AutoInctConst = require("autoincrid.autoincrid_const")

local AutoIncrCtrl = {}
local AutoIncrIdList = {}

local SERVER_PART_OFFSET = 11
local serverId
-- local isTestMode = skynet.getenv("isTestMode")

local function getServerPart()
    if not serverId then
        serverId = tonumber(skynet.getenv("serverId"))
        -- if isTestMode then
        --     serverId = 0
        -- end
    end
    return serverId
end


function AutoIncrCtrl.initAutoIncrId()
    for _,keyName in ipairs(AutoInctConst) do
        local maxId = dbHelp.call("autoincrid.getMaxIncrId", keyName, SERVER_PART_OFFSET)
        if maxId then
            local nMaxId = tonumber(maxId)
            assert(nMaxId ~= nil, "获取最大自增加ID失败，keyName = "..keyName.." 返回的maxId ="..maxId)
            AutoIncrIdList[keyName] = (nMaxId >> SERVER_PART_OFFSET)
        else
            AutoIncrIdList[keyName] = 0
        end
    end
end

function AutoIncrCtrl.getAutoIncrId(key)
    if AutoIncrIdList[key] then
        AutoIncrIdList[key] = AutoIncrIdList[key] + 1
        return (AutoIncrIdList[key] << SERVER_PART_OFFSET) + getServerPart()
    else
        local maxId = dbHelp.call("autoincrid.getMaxIncrId", key, SERVER_PART_OFFSET)
        if maxId then
            AutoIncrIdList[key] = (maxId >> SERVER_PART_OFFSET)
        else
            AutoIncrIdList[key] = 0
        end
        return AutoIncrCtrl.getAutoIncrId(key)
    end
end
return AutoIncrCtrl