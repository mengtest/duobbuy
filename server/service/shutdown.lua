local skynet = require("skynet")
local logger = require("log")
require("skynet.manager")
local context = require("common.context")
local clientHelper = require("common.client_helper")
clientHelper.registerProtos()
local shutdownSvc = require("service_base")
local command = shutdownSvc.command
local isProcess = false

function command.checkAllRoleLogout()
    if isProcess then return end
    isProcess = true

    print ("收到玩家数据落地确认消息, 开始处理日志落地")
    logger.Infof("收到玩家数据落地确认消息, 开始处理日志落地")
    -- context.callS2S(SERVICE.RECORD, "dumpRecord")
    -- context.callS2S(SERVICE.GAME_RANK, "dumpGameRank")
    print ("日志落地处理完毕 执行退出脚本 sh stop.sh")
    logger.Infof("日志落地处理完毕 执行退出脚本 sh stop.sh")
    print("shutdown success")
    logger.Infof("shutdown success")
    os.execute("sh stop.sh")
end

skynet.start(function()
    skynet.register(SERVICE.SHUTDOWN_SERVER)
    skynet.timeout(10 * 100, function()
        print("回馈超时 强行关闭服务")
        logger.Infof("回馈超时 强行关闭服务")
        command.checkAllRoleLogout()
        end)
    print("关闭服务入口")
    logger.Infof("关闭服务入口")
    context.callS2S(SERVICE.WATCHDOG, "loginSwitch", true)
    print("踢出所有在线用户")
    logger.Infof("踢出所有在线用户")
    context.callS2S(SERVICE.WATCHDOG, "kickAllRole")
    print("等待回调或超时")
    logger.Infof("等待回调或超时")
end)
