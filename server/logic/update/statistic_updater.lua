--[[
    该文件必须在agent_mgr服务上执行，限于更新agent
    首先通过调试控制台的list命令获取agent_mgr服务地址
    然后执行以下命令:
    连接debug端口 telnet 127.0.0.1 5056
    inject :06000012 ./logic/update/statistic_updater.lua
]]
local codecache = require("skynet.codecache")
local hotfix = require("common.hotfix")
local context = require("common.context")


local command = _P.lua.command

print(command.dayHandle, command.roundHandle)

function command.dayHandle()
end

function command.roundHandle()
end

print("------------ok")
