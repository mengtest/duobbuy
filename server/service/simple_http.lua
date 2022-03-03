local skynet = require "skynet"
local socket = require "socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
require("errorcode")
require("functions")
local json = require("json")
local table = table
local string = string

local mode = ...

if mode == "agent" then

local secretKey = skynet.getenv("secretKey")

-- 响应码规则随意即可，以后业务划分较细在做细分
local errorCodeMsg = {
	[0] = "OK",
	[1] = "Request Method No Support",
	[2] = "Params key is null",
	[3] = "secretKey is not match",
	[4]	= "serverId is null",
	[5] = "module is null",
	[6] = "method id null",
	[7] = "request module not exist",
	[8] = "request function not exist",
}

local function response(id, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
end

--[[
	验证post请求的body参数
	key、roleId、serverId、module、method必须包含
]]
local function checkParams(requestParams)
	if requestParams["secretKey"] ~= nil then
		if requestParams["secretKey"] ~= secretKey then
			return 3
		end
	else
		return 2
	end
	if requestParams["serverId"] == nil then
		return 4
	end
	if requestParams["module"] == nil then
		return 5
	end
	if requestParams["method"] == nil then
		return 6
	end
	return 0
end

skynet.start(function()
	skynet.dispatch("lua", function (_,_,id)
		socket.start(id)
		-- limit request body size to 8192 (you can pass nil to unlimit)
		local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
		if code then
			if code ~= 200 then
				response(id, code)
			else
				-- 根据参数请求对应的服务，等需求，请求的参数已经全部解开
				local tmp = {errorCode=0,data={}}
				if method ~= "POST" then
					tmp.errorCode = 1
					response(id, 200, table.concat(tmp,"\n"))
				else
					local requestParams = urllib.parse_query(body)

					tmp.errorCode 		= checkParams(requestParams) -- 验证请求参数
					if tmp.errorCode ~= 0 then
						tmp = json.encode(tmp)
						response(id, 200, tmp)
					else
						-- if pcall(function() local control = require(requestParams.module) end) then
						-- 	local control = require(requestParams.module)
						-- 	local method = requestParams.method
						-- 	if type(control.method) ~= "function" then
						-- 		tmp.errorCode = 8
						-- 	else
						-- 		tmp.data = control.method(requestParams)
						-- 	end
						-- else
						-- 	tmp.errorCode = 7
						-- end
						local method = requestParams.method
						local controlName = requestParams.module
						local control = require("portal.portal_ctrl")
						local func = control[method]
						-- dump(requestParams)
						if func and type(func) == "function" then
							tmp.errorCode, tmp.data = func(requestParams["param[0]"],
								requestParams["param[1]"],requestParams["param[2]"],requestParams["param[3]"],requestParams["param[4]"],requestParams["param[5]"],
								requestParams["param[6]"],requestParams["param[7]"],requestParams["param[8]"],requestParams["param[9]"],requestParams["param[10]"])
							tmp.message = errmsg(tmp.errorCode)
							response(id, 200, json.encode(tmp))
						end
					end
				end

				
				-- if header.host then
				-- 	table.insert(tmp, string.format("host: %s", header.host))
				-- end
				-- local path, query = urllib.parse(url)
				-- table.insert(tmp, string.format("path: %s", path))
				-- if query then
				-- 	local q = urllib.parse_query(query)
				-- 	for k, v in pairs(q) do
				-- 		table.insert(tmp, string.format("query: %s= %s", k,v))
				-- 	end
				-- end
				-- table.insert(tmp, "-----header----")
				-- for k,v in pairs(header) do
				-- 	table.insert(tmp, string.format("%s = %s",k,v))
				-- end
				-- table.insert(tmp, "-----body----\n" .. body)
				-- response(id, code, table.concat(tmp,"\n"))
			end
		else
			if url == sockethelper.socket_error then
				skynet.error("socket closed")
			else
				skynet.error(url)
			end
		end
		socket.close(id)
	end)
end)

else

local whiteIps = skynet.getenv("whiteIps") or ""
print("-------------------------------------")
print("The White IPs: " .. whiteIps)
print("-------------------------------------")
whiteIps = string.split(whiteIps, ",")
for i, ip in ipairs(whiteIps) do
	assert(#ip > 0)
	whiteIps[i] = string.trim(ip)
end

skynet.start(function()
	local agent = {}
	local agentNum = tonumber(skynet.getenv("http_agent_num")) or 1
	for i= 1, agentNum do
		agent[i] = skynet.newservice(SERVICE_NAME, "agent")
	end
	local balance = 1
	print("simple_http server has started")
	local id = socket.listen("0.0.0.0", skynet.getenv("http_port"))
	socket.start(id , function(id, addr)
		local isAllowed = false
		for _, ip in ipairs(whiteIps) do
			if ip == string.sub(addr, 1, #ip) or ip == "*" then
				isAllowed = true
				break
			end
		end
		if not isAllowed then
			skynet.error(string.format("%s connected, but IP is not white IP", addr))
			socket.close(id)
			return
		end

		skynet.error(string.format("%s connected, pass it to agent :%08x", addr, agent[balance]))
		skynet.send(agent[balance], "lua", id)
		balance = balance + 1
		if balance > #agent then
			balance = 1
		end
	end)
end)

end