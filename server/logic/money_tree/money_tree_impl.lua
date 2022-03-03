local moneyTreeCtrl = require("money_tree.money_tree_ctrl")
local moneyTreeImpl = {}

function moneyTreeImpl.getInfo(roleId)
	return moneyTreeCtrl.getInfo(roleId)
end

function moneyTreeImpl.lottery(roleId, num)
	return moneyTreeCtrl.lottery(roleId, num)
end

function moneyTreeImpl.getGoodsRecords(roleId)
	return moneyTreeCtrl.getGoodsRecords(roleId)
end

return moneyTreeImpl