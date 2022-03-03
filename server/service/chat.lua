local skynet = require("skynet")

skynet.start(function()
	skynet.newservice("chat_svc")
end)
