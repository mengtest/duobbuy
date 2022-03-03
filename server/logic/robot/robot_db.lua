local skynet = require("skynet")
local logger = require("log")
local context = require("common.context")
local testDb = {}
function testDb.testInsert(db, count)
    print ("执行次数 = ", count)
    local startTime = skynet.time()
    -- print (startTime)
    -- logger:P("DB Insert 测试 startTime = %s", startTime)
    for i = 1, count do
        local data = {}
        data._id = context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "Test")
        -- print (data._id)
        data.createTime = os.time()
        data.changeNameCount = 0         -- 用于标记第一次免费改名
        data.nickname = data.nickname or table.concat({"拓荒者", data._id})

        db.Test:insert(data)
    end
    -- print (skynet.time())
    return skynet.time() - startTime
end


function testDb.testUpdate(db, count)
    local startTime = skynet.time()
    -- logger:P("DB Insert 测试 startTime = %s", startTime)
    local logoutInfo = {
        lastLogoutTime = skynet.time(),
        leaveScene = 100,
        leavePosX = 30000,
        leavePosY = 600,
    }

    for i = 1, count do
        local doc = {
            query = {_id = i},
            update = {["$set"] = logoutInfo},
            upsert = true,
        }
        db.Test:findAndModify(doc)
    end
    return skynet.time() - startTime
end

function testDb.testFind(db, count)
    local startTime = skynet.time()
    for i = 1, count do
        db.Test:findOne({_id = i})
    end
    return skynet.time() - startTime
end


return testDb