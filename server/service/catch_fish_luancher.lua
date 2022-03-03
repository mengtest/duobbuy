local skynet  	= require("skynet")
local clientHelper = require("common.client_helper")
clientHelper.registerProtos()

skynet.start(function()
	skynet.newservice("debug_console")
	skynet.newservice("catch_fish")
	skynet.exit()
end)
