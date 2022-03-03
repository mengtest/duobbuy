local skynet  	= require("skynet")

skynet.start(function()
    skynet.newservice("globallog")
    skynet.newservice("gamelog")
    print("log server start")
    skynet.exit()
end)
