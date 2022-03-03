local skynet = require("skynet")
local netpack = require("netpack")
local TestClient = require("robot.robot_client")
local logger = require("log")
local protobuf = require("protobuf")
require("errorcode")
require("functions")
local protoMap = require("proto_map")

local index = ...
index = tonumber(index)

local svcCount = tonumber(skynet.getenv("svcCount"))
local clientsPerSvc = tonumber(skynet.getenv("clientsPerSvc")) --启动客户端数量
local loginHost = skynet.getenv("loginHost")			--登录验证服地址
local loginUrl = skynet.getenv("loginUrl")		--登录验证服网站
local loginInterval = skynet.getenv("loginInterval") --登录间隔
local heartbeatInterval = tonumber(skynet.getenv("heartbeatInterval")) --心跳检查间隔
local sampleDataPath = skynet.getenv("sampleDataPath")
local sampleData = skynet.getenv("sampleData")  --采样样本文件序列
local pbPath = skynet.getenv("pbpath")
local serverId = tonumber(skynet.getenv("serverId"))
local accountPrefix = skynet.getenv("accountPrefix")
local accountStartIndex = tonumber(skynet.getenv("accountStartIndex"))
local password = skynet.getenv("password")

local clients = {}
local runningClientCount = 0
local samples = {}
local curAccountIndex = accountStartIndex

local startClient

local function getClientAccount()
	curAccountIndex = curAccountIndex + 1
	local account = accountPrefix .. "_" .. index .. "_" .. curAccountIndex
	return account
end

local function completedCallback(client, completed)
	if clients[client:getAccount()] then
		runningClientCount = runningClientCount - 1
		clients[client:getAccount()] = nil
	end
end

local function initOneSample(fileName)
	local path = sampleDataPath .. string.trim(fileName) .. ".pdt"
	local file = io.open(path, "rb")
	assert(file, string.format("sample file[%s] is invalid", path))
	local data = file:read("*a")
	file:close()

	local sample = {}
	local offset = 0
	while offset < #data - 1 do
		local request = {}
		request.delay = protobuf.decode_int32(data, offset)
		local sz = protobuf.decode_int16(data, offset + 4)
		request.buffer = string.sub(data, offset + 5, offset + 4 + sz + 2)
		-- dump(request)
		sample[#sample + 1] = request
		offset = offset + 6 + sz
	end
	return sample
end

local function initSamples()
	local files = string.split(sampleData, ",")
	for _, fileName in pairs(files) do
		samples[#samples + 1] = initOneSample(fileName)
	end
	startClient()
	-- skynet.timeout(loginInterval * 100, startClient)
end

local function getSample()
	local index = math.rand(1, #samples)
	local sample = samples[index]
	return sample
end

startClient = function()
	if runningClientCount >= clientsPerSvc then
		-- printf("reached max clients[%d]", runningClientCount)
		skynet.timeout(loginInterval * 100, function() startClient() end)
		return
	end

	local account = getClientAccount()
	local client = TestClient.new(protoMap.protos, completedCallback)
	if not client:login(loginHost, loginUrl, serverId, account, password) then
		logger.Debugf("start client[%s] error", account)
		return
	end

	clients[account] = client
	runningClientCount = runningClientCount + 1
	logger.Debugf("start client[%s] ok, total clients[%s]", account, runningClientCount)
	-- client:heartbeat(heartbeatInterval)
	client:start(getSample())

	skynet.timeout(loginInterval * 100, function() startClient() end)
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
	print("robot server start")
	registerAllProtos()
	skynet.timeout(1, initSamples)
end
)


