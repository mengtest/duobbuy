require("skynet.manager")
local skynet    = require("skynet")
local mongo = require("mongo")
local playerOps = require("log.player_ops")

local protoMap = require("proto_map")

local db
local collections = {}
local logServerId = 0
local dumpInterval = 0
local dumpMinCount = 0
local playerOpLogs = {}

local function connect()
    logServerId = tonumber(skynet.getenv("serverId"))
    dumpInterval = tonumber(skynet.getenv("dumpInterval")) or 0
    dumpMinCount = tonumber(skynet.getenv("dumpMinCount")) or 1
    local dbhost = skynet.getenv("dbhost")
    local dbport = skynet.getenv("dbport")
    local dbname = skynet.getenv("dbname")
    local username = skynet.getenv("username")
    local password = skynet.getenv("password")
    local authmod = skynet.getenv("authmod")

    local conf = {host = dbhost, port = dbport, username = username, password = password, authmod = authmod}
    local dbclient = mongo.client(conf)
    db = dbclient:getDB(dbname)
end

local function setPlayerOpExtraInfo(data, dbsvc)
    local op = playerOps[data.protoId]
    if op then
        local proto = protoMap.protos[data.protoId]
        if proto.type == PROTO_TYPE.C2S then
            data.request, data.response = op(dbsvc, data.request, data.response)
        else
            data.response = op(dbsvc, data.response)
        end
    end
end

local function dumpPlayerOp(collection, data)
    playerOpLogs[#playerOpLogs + 1] = data
    if #playerOpLogs < dumpMinCount then
        return
    end
    collection:batch_insert(playerOpLogs)
    playerOpLogs = {}
end

local function onDumpPlayerOp()
    local collection = collections["player_op"]
    if collection then
        collection:batch_insert(playerOpLogs)
        playerOpLogs = {}
    end
    skynet.timeout(dumpInterval * 100, onDumpPlayerOp)
end

local lua = {}
function lua.dispatch(session, address, catalog, data, dbsvc)
    if not db then
        return
    end
    
    data.time = os.time()
    data.serverId = logServerId
    
    local collection = collections[catalog]
    if not collection then
        collection = db:getCollection(catalog)
        collections[catalog] = collection
    end
    
    if catalog == "player_op" then
        pcall(setPlayerOpExtraInfo, data, dbsvc)
        dumpPlayerOp(collection, data)
        return
    end

    collection:insert(data)
end
skynet.dispatch("lua", lua.dispatch)

skynet.start(function()
    local ok, msg = pcall(connect)
    if not ok then
        print(msg)
    else
        if dumpInterval > 0 then
            skynet.timeout(dumpInterval * 100, onDumpPlayerOp)
        end
    end
    skynet.register(SERVICE.GAMELOG)
end)