local eggCtrl = require("egg.egg_ctrl")
local eggImpl = {}

function eggImpl.getInfo(roleId)
	return eggCtrl.getInfo(roleId)
end

function eggImpl.openEgg(roleId, positionId)
	return eggCtrl.openEgg(roleId, positionId)
end

return eggImpl