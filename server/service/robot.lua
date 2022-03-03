local skynet  	= require("skynet")
local logger  	= require("log")

local svcCount = tonumber(skynet.getenv("svcCount"))

skynet.start(function()
	for i = 1, svcCount do
		skynet.newservice("robot_svc",i)
	end
	print("robot server start")
	skynet.exit()
end)