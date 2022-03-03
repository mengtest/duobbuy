local skynet = require("skynet")
local dbHelp = require("common.db_help")

local function callDb(svc, cmd, ...)
    if not svc then
        svc = dbHelp.getDbSvc()
    end
    return skynet.call(svc, "lua", cmd, ...)
end

local getGoodsId = function(dbsvc, itemId) return callDb(dbsvc, "goods.getGoodsId", itemId, true) end

local PlayerOps = {
    -- [M_Bag.useItem.id] = function(dbsvc, request, response) 
    --         request.goodsId = getGoodsId(dbsvc, request.itemId) 
    --         return request, response
    --     end,
    }

return PlayerOps
