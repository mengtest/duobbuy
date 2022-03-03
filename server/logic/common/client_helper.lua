local skynet = require("skynet")
local dbHelp = require("common.db_help")
protobuf = require("protobuf")
local queue = require("skynet.queue")
local protoMap = require("proto_map")
local json = require("json")
local logger = require("log")
local clientRequestIdList = {}
local queueEnter = queue()
local function queueFunc(ret, func, roleId, data)
  local ok , msg = xpcall(
    function()
    local ec, result = func(roleId, data)
    ret[1] = ec
    ret[2] = result
    end ,debug.traceback)
    if not ok then
         error(msg)
    end
end

local function decodeData(data)
	local vtype = type(data)
	if vtype == "table" then
		for k, v in pairs(data) do
			decodeData(v)
		end
	end
end

local ClientHelper = {}

local function recordProto(proto, request, ec, response)
    local roleId = ClientHelper.ServiceBase and ClientHelper.ServiceBase.roleId
    local dbsvc = dbHelp.getDbSvc()
    if proto.log == PROTO_LOG.ALL then
        logger.Game("player_op", {roleId = roleId, protoId = proto.id, request = request, ec = ec, response = response}, dbsvc)
    elseif proto.log == PROTO_LOG.EC then
        logger.Game("player_op", {roleId = roleId, protoId = proto.id, request = request, ec = ec}, dbsvc)
    elseif proto.log == PROTO_LOG.REQUEST then
        logger.Game("player_op", {roleId = roleId, protoId = proto.id, request = request}, dbsvc)
    end
end

local function dispatch(client, requestId, proto, data)
    local ok , msg = xpcall(function()
        local ec, ret = ClientHelper.dispatch(client, requestId, proto, data)
        -- recordProto(proto, data, ec, ret)
        end, debug.traceback)

    if not ok then
         ClientHelper.send(client, requestId, proto, SystemError.serviceIsStoped)
         error(msg)
    end

end

function ClientHelper.dispatch(client, requestId, proto, data)
    if not clientRequestIdList[client] then clientRequestIdList[client] = 0 end

    if clientRequestIdList[client] >= 32767 then
        clientRequestIdList[client] = 0
    end

    if requestId <= clientRequestIdList[client] then
        logger.Errorf("more requestId proto = %s, requestId = %d", proto.name, requestId)
        return SystemError.protoNotExisits
    end
    clientRequestIdList[client] = requestId

    local ServiceBase = ClientHelper.ServiceBase
    if requestId == nil then
        return SystemError.unknown
    end
    if proto.errorCode ~= nil then
        ClientHelper.send(client, requestId, proto, proto.errorCode)
        return proto.errorCode
    end
    -- if proto.log ~= PROTO_LOG.NONE then
    --     logger.Debugf("the message from client:%s.%s", proto.module, proto.name)
    -- end
    local mod = ServiceBase.modules[proto.module]
    if mod == nil then
        logger.Errorf("the module[%s] object is not found in this service", proto.module)
        ClientHelper.send(client, requestId, proto, SystemError.notImplement)
        return SystemError.notImplement
    end
    local func = mod[proto.name]
    if func == nil then
        logger.Errorf("the implement of proto[%s] is not found in the module[%s]", proto.name, proto.module)
        ClientHelper.send(client, requestId, proto, SystemError.notImplement)
        return SystemError.notImplement
    end

    local ec, ret
    if ServiceBase.isAgent then
        local rec = {}
        queueEnter(queueFunc, rec, func, ServiceBase.roleId, data)
        ec =  rec[1]
        ret =  rec[2]
    elseif proto.module == M_Auth.module then
        ec, ret = func(client, data, requestId)
    else
        local roleId = onlines[client]
        if roleId == nil then
            logger.Errorf("roleId is nil, proto[%s], service[%s] ,client[%x]", proto.fullname, proto.service, client)
            ClientHelper.send(client, requestId, proto, SystemError.unknown)
            return SystemError.unknown
        end
        ec, ret = func(roleId, data)
    end

    if ec == SystemError.forward then
        return SystemError.forward
    elseif ec ~= SystemError.success then
        if ec == nil then
            logger.Errorf("proto[%s] not return error code", proto.fullname)
            ec = SystemError.unknown
        end
        if proto.log ~= PROTO_LOG.NONE then
            logger.Infof("the implement of proto[%s.%s] return error[%s]"
                , proto.module, proto.name, errmsg(ec))
        end
    else
        if ret == nil and proto.response ~= nil then
            logger.Errorf("proto[%s] must has return value error[%s]", proto.fullname, errmsg(ec))
        end
    end
    -- if proto.log ~= PROTO_LOG.NONE then
    --     logger.Debugf("proto[%s.%s] ret = [%s] fd = [%s]", proto.module, proto.name, errmsg(ec), client)
    -- end
    ClientHelper.send(client, requestId, proto, ec, ret)
    return ec, ret
end

function ClientHelper.redirect(client, buffer)
	dispatch(client, ClientHelper.unpack(buffer))
end

function ClientHelper.send(client, requestId, ...)
	skynet.send(SERVICE.WATCHDOG, "lua", "responseC2S", client, ClientHelper.pack(requestId, ...))
end

local function allocBuffer(size)
	local buffer = ""
	for i = 1, size do
		buffer = buffer ..  "0"
	end
	return buffer
end

local encodeBuffers = {}
function ClientHelper.initEncodeBuffers(count)
	for i = 1, count do
		encodeBuffers[i] = allocBuffer(i)
	end
end
ClientHelper.initEncodeBuffers(16)

function ClientHelper.pack(requestId, proto, ec, data)
    proto = protoMap.protos[proto.id]
	local buffer = nil
	local offset = 4
	if proto.type == PROTO_TYPE.C2S then
		offset = 8
	end

	if proto.response then
		if ec == SystemError.success and data == nil then
			--logger.Errorf("proto[%s.%s] must has response[%s]", proto.module, proto.name, proto.response)
			buffer = encodeBuffers[offset]
		elseif data ~= nil then
			if proto.response == "int8" then
				buffer = encodeBuffers[offset + 1]
				protobuf.encode_int8(buffer, offset, data)
			elseif proto.response == "int16" then
				buffer = encodeBuffers[offset + 2]
				protobuf.encode_int16(buffer, offset, data)
			elseif proto.response == "int32" then
				buffer = encodeBuffers[offset + 4]
				protobuf.encode_int32(buffer, offset, data)
         elseif proto.response == "int64" then
				buffer = encodeBuffers[offset + 8]
				protobuf.encode_int64(buffer, offset, data)
			else
            -- if ClientHelper.ServiceBase and ClientHelper.ServiceBase.isAgent then
                -- buffer = encodeBuffers[offset]
            -- else
                -- buffer = protobuf.encode_ex(proto.response, data, offset)
                buffer = protobuf.encode(proto.response, data)

                if buffer then
                    buffer = encodeBuffers[offset] .. buffer
                end
            -- end
			end
			if buffer == false then
				--logger.Errorf("encode [%s] occured error", proto.response)
				ec = SystemError.serialize
				buffer = encodeBuffers[offset]
			end
		else
			buffer = encodeBuffers[offset]
		end
	else
		if data ~= nil and proto.module then
			--logger.Errorf("proto[%s.%s] can not has response", proto.module, proto.name)
		end
		buffer = encodeBuffers[offset]
	end
	protobuf.encode_int16(buffer, 0, #buffer - 2)
	protobuf.encode_int16(buffer, 2, proto.id)
	if proto.type == PROTO_TYPE.C2S then
		protobuf.encode_int16(buffer, 4, requestId)
		protobuf.encode_int16(buffer, 6, ec)
	end
	return buffer
end

function ClientHelper.unpack(buffer)
	local protoId = protobuf.decode_int16(buffer, 0)
	local requestId = protobuf.decode_int16(buffer, 2)
	local proto = protoMap.protos[protoId]
	if proto then
		if proto.request == nil then
			return requestId, proto
		end
		local data = nil
		local offset = 4
		if proto.request == "int8" then
			data = protobuf.decode_int8(buffer, offset)
		elseif proto.request == "int16" then
			data = protobuf.decode_int16(buffer, offset)
		elseif proto.request == "int32" then
			data = protobuf.decode_int32(buffer, offset)
      elseif proto.request == "int64" then
			data = protobuf.decode_int64(buffer, offset)
		else
			data = protobuf.decode_ex(proto.request, buffer, offset)
        if data then
            decodeData(data)
        end
		end
		if data == false then
			logger.Errorf("proto[%s], decode [%s] occured error", proto.fullname, proto.request)
			return requestId, {id = protoId, type = PROTO_TYPE.C2S, errorCode = SystemError.serialize}
		end
		return requestId, proto, data
	else
		logger.Errorf("invalid proto id[0x%x]", protoId)
		--skynet.kill(skynet.self())
		return requestId, {id = protoId, type = PROTO_TYPE.C2S, errorCode = SystemError.protoNotExisits}
	end
end

function ClientHelper.registerProtos()
    local pbpath = skynet.getenv("pbpath")
    if pbpath then
        for _, file in ipairs(protoMap.files) do
            protobuf.register_file(pbpath .. file)
        end
    end
end

-- ClientHelper.register()

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	pack = ClientHelper.pack,
	unpack = ClientHelper.unpack,
	dispatch = dispatch,
}

return ClientHelper