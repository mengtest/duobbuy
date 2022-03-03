local fruitCtrl = require("fruit.fruit_ctrl")
local fruitImpl = {}

function fruitImpl.roll(roleId)
	local ec, data = fruitCtrl.roll(roleId)
	if ec ~= SystemError.success then
		return ec
	end
	return ec, {nums = data}
end

function fruitImpl.getInfo(roleId)
	return SystemError.success, fruitCtrl.getFreeNum(roleId)
end

return fruitImpl