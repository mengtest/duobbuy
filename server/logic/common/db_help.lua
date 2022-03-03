--db管理类
local skynet = require("skynet")
local json = require("json")
require("proto_map")
require("functions")
--require("monitor.monitor_ctrl")
local dbHelp = {}

local dbSvc
local dbIndex

local function getDbSvc()
    if not dbSvc then
        dbSvc = skynet.call(SERVICE.MAIN_DB, "lua", "getSvc")
    end
    return dbSvc
end

function dbHelp.getDbSvc()
    return getDbSvc()
end

function dbHelp.send(cmd, ...)
    local svc = getDbSvc()
    skynet.send(svc, "lua", cmd, ...)
end

function dbHelp.call(cmd, ...)
    local svc = getDbSvc()
    local ret = skynet.call(svc, "lua", cmd, ...)
    return ret
end

--[[
	压测模式下id生成函数
    @param type 自增字段类型
	@param roleId 当前玩家角色ID
	@results 返回最终的实际的ID
]]
function dbHelp.getTestModeId(fieldType, roleId)
	return skynet.call(SERVICE.MAIN_DB, "lua", "getTestModeId", fieldType, roleId)
end

return dbHelp