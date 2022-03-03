local skynet = require("skynet")
local json   = require("json")
local netpack= require("netpack")
require("functions")

local protoMap = require("proto_map")

local ProtoRecorder = class("ProtoRecorder")

local FILTER_TYPE_REQUEST = 1
local FILTER_TYPE_RESPONSE = 2
local FILTER_TYPE_ALL = 3

function ProtoRecorder:ctor()
	self._datas = {}
end

function ProtoRecorder:init(logPath, flushInterval, filterConf)
	self._log = io.open(logPath, "w+b")
	if not self._log then
		return false
	end
	
	if filterConf then
		self:_initFilter(filterConf)
	end

	self._flushInterval = flushInterval
	if self._flushInterval then
		self:flush()
	end
	return true
end

function ProtoRecorder:log(isRequest, protoId, buffer)
	-- local toLog, headerOnly = self:_filter(isRequest, protoId)
	-- if not toLog then
		-- return false
	-- end

	-- if not isRequest then
		-- return false
	-- end
	local delay = -1
	if not self._lastestLogTime then
		self._lastestLogTime = skynet.now() * 10
	else
		local now = skynet.now() * 10
		delay = now - self._lastestLogTime
		self._lastestLogTime = now
	end
	
	local buf = "1234"
	protobuf.encode_int32(buf, 0, delay)
	buffer = buf .. buffer
	self:_write(buffer)
end

function ProtoRecorder:find(params)
end

function ProtoRecorder:toFirst()
end

function ProtoRecorder:toLast()
end

function ProtoRecorder:toNext(pos)
end

function ProtoRecorder:clear()
end

function ProtoRecorder:flush()
	if self._log then
		self._log:flush()
		skynet.timeout(self._flushInterval * 100, function() self:flush() end)
	end
end

function ProtoRecorder:readAll()
	return self._log:read("*a")
end

function ProtoRecorder:destroy()
	if self._log then
		self._log:flush()
		self._log:close()
		self._log = nil
	end
end
------------------------------------------------------------------------------------------
function ProtoRecorder:_write(buffer)
	self._log:write(buffer)
end

function ProtoRecorder:_filter(isRequest, protoId)
	local filter = self._filters[protoId]
	if not filter then
		return false
	end

	if filter.type == FILTER_TYPE_ALL
		or (isRequest == false and filter.type == FILTER_TYPE_REQUEST)
		or (isRequest == true and filter.type == FILTER_TYPE_RESPONSE)then
		return true, filter.headerOnly
	else
		return false
	end
end

function ProtoRecorder:_initFilter(filterConf)
	self._filters = clone(protoMap)
	for _, item in pairs(filterConf) do
		local filter = self._filters[item.protoId]
		if filter then
			filter.type = item.type
			filter.headerOnly = item.headerOnly
		end
	end
end

return ProtoRecorder

