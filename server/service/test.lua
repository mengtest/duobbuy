local skynet  	= require("skynet")
local logger  	= require("log")

local svcCount = tonumber(skynet.getenv("svcCount"))

skynet.start(function()
	for i = 1, svcCount do
		skynet.newservice("test_svc",i)
	end
	print("test server start")
	skynet.exit()
end)
