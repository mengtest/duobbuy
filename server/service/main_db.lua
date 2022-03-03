require("skynet.manager")
local skynet  	= require("skynet")
require("proto_map")
require("functions")
--require("monitor.monitor_ctrl")
local AutoIncridCtrl = require("autoincrid.autoincrid_ctrl")

local svcs = {}

local index = 1
local function initSvcPool()
	local dbSvcCount = skynet.getenv("dbSvcCount")
	for i = 1, dbSvcCount do
		svcs[#svcs  +1] = skynet.newservice("main_db_svc")
	end
end

local function getSvc()
	local svc = svcs[index]
	index = index + 1
	if index > #svcs then
		index = 1
	end
	return svc
end

local function getAutoIncrId(key)
    return AutoIncridCtrl.getAutoIncrId(key)
end

--[[
	压测模式下id生成函数
    @param type 自增字段类型
	@param roleId 当前玩家角色ID
	@results 返回最终的实际的ID
]]
local __testModeIds = {}
local function getTestModeId(fieldType, roleId)
    local ids = __testModeIds[fieldType]
    if not ids then
        ids = {}
        __testModeIds[fieldType] = ids
    end

    local id = ids[roleId]
    if not id then
        id = 1
    else
        id = id + 1
    end
	ids[roleId] = id
	local id = covertToTestModeId(roleId, id)
	return id
end

local lua = {}
function lua.dispatch(session, address, cmd, ...)
    local svc = getSvc()
    if session > 0 then
        if cmd == "getSvc" then
            skynet.ret(skynet.pack(getSvc()))
        elseif cmd == "getTestModeId" then
            skynet.ret(skynet.pack(getTestModeId(...)))
        elseif cmd == "getAutoIncrId" then
            skynet.ret(skynet.pack(getAutoIncrId(...)))
        else
            skynet.ret(skynet.pack(skynet.call(svc, "lua", cmd, ...)))
        end
    else
        skynet.send(svc, "lua", cmd, ...)
    end
end
skynet.dispatch("lua", lua.dispatch)


skynet.start(function()
	initSvcPool()
	skynet.register(SERVICE.MAIN_DB)
    skynet.timeout(1, function() AutoIncridCtrl.initAutoIncrId() end)
end)