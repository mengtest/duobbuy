local skynet = require("skynet")
local redMoneyDb = {}

function redMoneyDb.recordLog(db, log)
	local data = {log = log, createTime = skynet.time()}
	db.RedMoney:insert(data)
end

return redMoneyDb