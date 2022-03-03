local diskCtrl = require("disk.disk_ctrl")

local diskImpl = {}

function diskImpl.canRoll(roleId)
	local rollFlag, critFlag = diskCtrl.canRoll(roleId)
	if rollFlag then
		return SystemError.success
	end
	return DiskError.canRoll
end

function diskImpl.roll(roleId)
	return diskCtrl.roll(roleId)
end

return diskImpl