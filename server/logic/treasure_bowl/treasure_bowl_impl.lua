local treasureBowlImpl = {}

local treasureBowlCtrl = require("treasure_bowl.treasure_bowl_ctrl")

function treasureBowlImpl.getInfo(roleId)
	return treasureBowlCtrl.getInfo(roleId)
end

function treasureBowlImpl.join(roleId)
	return treasureBowlCtrl.join(roleId)
end

return treasureBowlImpl