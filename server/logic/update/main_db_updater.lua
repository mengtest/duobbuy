--连接debug端口 telnet 127.0.0.1 5053
--inject :0300000a ./logic/update/main_db_updater.lua

local hotfix = require("common.hotfix")
local skynet = require("skynet")

local luaProto = hotfix.getupvalue(skynet.dispatch, "proto")["lua"]
local getSvc = hotfix.getupvalue(luaProto.dispatch, "getSvc")
local svcs = hotfix.getupvalue(getSvc, "svcs")

local fixFile = "./logic/update/main_db_svc_updater.lua"
local chunk = hotfix.getChunk(fixFile)

for _, svc in pairs(svcs) do
	local output = skynet.call(svc, "debug", "RUN", chunk, fixFile)
	print(output)
end


