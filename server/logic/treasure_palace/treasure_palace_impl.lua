local treasurePalaceCtrl = require("treasure_palace.treasure_palace_ctrl")
local treasurePalaceImpl = {}

function treasurePalaceImpl.getInfo(roleId)
	return treasurePalaceCtrl.getInfo(roleId)
end

function treasurePalaceImpl.dice(roleId)
	return treasurePalaceCtrl.dice(roleId)
end

function treasurePalaceImpl.openBox(roleId)
	return treasurePalaceCtrl.openBox(roleId)
end

function treasurePalaceImpl.getGoodsRecords(roleId)
	return treasurePalaceCtrl.getGoodsRecords(roleId)
end
return treasurePalaceImpl