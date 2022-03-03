local skynet = require("skynet")
local netpack = require("netpack")
local TestClient = require("test.test_client")
local logger = require("log")
local protobuf = require("protobuf")
require("errorcode")
require("functions")
local protoMap = require("proto_map")

local index = ...
index = tonumber(index)

local svcCount = tonumber(skynet.getenv("svcCount"))
local clientsPerSvc = tonumber(skynet.getenv("clientsPerSvc")) --启动客户端数量
local clientsBegin = tonumber(skynet.getenv("clientsBegin")) 
local loginHost = skynet.getenv("loginHost")			--登录验证服地址
local loginUrl = skynet.getenv("loginUrl")		--登录验证服网站
local loginInterval = skynet.getenv("loginInterval") --登录间隔
local heartbeatInterval = tonumber(skynet.getenv("heartbeatInterval")) --心跳检查间隔
local pbPath = skynet.getenv("pbpath")
local serverId = tonumber(skynet.getenv("serverId"))
local password = skynet.getenv("password")
local serverHost = skynet.getenv("serverHost")
local serverPort = tonumber(skynet.getenv("serverPort"))

local clients = {}
local runningClientCount = 0

local startClient

local function getClientAccount()
end

local function completedCallback(client, completed)
	if clients[client:getAccount()] then
		runningClientCount = runningClientCount - 1
		clients[client:getAccount()] = nil
	end
end

local lastRecordAt = 0
startClient = function()	
	skynet.timeout(5, startClient)

	local now = os.time()
	if now - lastRecordAt > 2 then
		lastRecordAt = now
		local StatusCollect = {}
		for _,client in pairs(clients) do
			local status = client:getStatus()
			if not StatusCollect[status] then
				StatusCollect[status] = 0
			end
			StatusCollect[status] = StatusCollect[status] + 1
		end
		print("...........")
		print("...totoal robot num:"..clientsPerSvc)
		print("...curr robot num:"..table.nums(clients))
		for status,num in pairs(StatusCollect) do
			print("..."..status.." num:"..num)
		end
		print("...........")
	end

	if runningClientCount < clientsPerSvc then
		runningClientCount = runningClientCount + 1
		local account = "robot"..(clientsBegin + runningClientCount)
		local client = TestClient.new(protoMap.protos, completedCallback)
		if not client then return end
		clients[account] = client
		client:init(loginHost, loginUrl, serverId, account, password, serverHost, serverPort)
		client:start()
		client:catchFish()
	end
end

checkStatus = function ()
	skynet.timeout(1000, checkStatus)
	if runningClientCount < clientsPerSvc then
		return
	end
	for _,client in pairs(clients) do
		local status = client:getStatus()
		if status ~= "捕鱼中" then
			client:reset()
		end
	end
end

local function registerAllProtos()
	for _, file in ipairs(protoMap.files) do
		local f = io.open(pbPath .. file, "rb")
		local buffer = f:read("*a")
		f:close()
		assert(buffer, string.format("pb file[%s] is invalid", file))
		protobuf.register(buffer)
	end
end

skynet.start(function()
	registerAllProtos()
	skynet.timeout(1, checkStatus)
	skynet.timeout(1, startClient)
	print("test svc server start")
end
)


