local hotfix = require("common.hotfix")
local skynet = require("skynet")

local luaProto = hotfix.getupvalue(skynet.dispatch, "proto")["lua"]
local modules = hotfix.getupvalue(luaProto.dispatch, "modules")

local moneyTreeDb = modules.moneyTree
function moneyTreeDb.initMoneyTreeInfo(db, info)
	for k,data in pairs(info) do
		db.MoneyTree:safe_insert(data)
	end
end

local wishPoolDb = modules.wishPool
function wishPoolDb.initWishPoolInfo(db, info)
	for k,data in pairs(info) do
		db.WishPoolTotal:safe_insert(data)
	end
end

print("ok--------------")