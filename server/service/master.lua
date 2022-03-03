local skynet = require("skynet")

skynet.start(function()
	print("master server start")
	--skynet.newservice("debug_console", 9001)
	skynet.exit()
end)
