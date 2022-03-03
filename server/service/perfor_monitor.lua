local skynet = require("skynet")
local context 	= require("common.context")
local clientHelper = require("common.client_helper")
clientHelper.registerProtos()
require("functions")
require("skynet.manager")

local monitorSvc = require("service_base")
local command = monitorSvc.command


-- 状态注册
function command.notifySerivceStatus(serverName)
    isRegistered = true
end

local isRegistered = false
local function registerSerivce()
    if not isRegistered then
        context.sendS2S(SERVICE.AUTH, "notifySerivceStatus", SERVICE.MONITOR)
		isRegistered = true
    end
end

local function printFile (...)
    -- print (...)
    skynet.error(...)
end
local monitorList = {}
function command.proFunc(funName, isEnd)
    if not monitorList[funName] then
        monitorList[funName] = {
        beginCount = 0,     -- 开始次数
        endCount = 0,       -- 结束次数
        useTimeCount = 0,   -- 总耗时  算法 当isEnd时 用当前的时间 - 上次开始执行事件 且叠加
        lastProcessTime = 0,    -- 上次处理时间
        }
    end
    if not isEnd then
        monitorList[funName].beginCount = monitorList[funName].beginCount + 1
        monitorList[funName].lastProcessTime = skynet.time()
    else
        monitorList[funName].endCount = monitorList[funName].endCount + 1
        local useTime = skynet.time() - monitorList[funName].lastProcessTime
        monitorList[funName].useTimeCount = monitorList[funName].useTimeCount + useTime
    end
end

-- 输出所有收集到的信息
function command.dump()
    skynet.timeout(10 * 100, function() command.dump() end)
    printFile("--------------all FucntionInfo---------- serverTime :", skynet.now()/100)
    printFile("::::::::::::'ART':argTime 'DC':diffCount(B-E) 'B/E':beginCount/endCount 'AT':allTimeCount::::::::::::")
    for funName, funInfo in pairs(monitorList) do
        local beginCount = funInfo.beginCount or 1
        if beginCount == 0 then beginCount = 1 end
        local arg = funInfo.useTimeCount / beginCount
        local diffCount = funInfo.beginCount - funInfo.endCount
        printFile(string.format("[%s], ART = %s, DC = %s, B/E[%s,%s], AT = %s",funName, arg, diffCount, funInfo.beginCount, funInfo.endCount, funInfo.useTimeCount))
    end

    printFile("--------------------------------------\n")
end

-- 重置
function command.reset()
    monitorList = {}
end
skynet.start(function ()
    monitorSvc.start()
    -- skynet.newservice("debug_console")
    skynet.register(SERVICE.MONITOR)
	print("perfor_monitor start")
    -- command.dump()
    registerSerivce()
end)

-- skynet.start()
