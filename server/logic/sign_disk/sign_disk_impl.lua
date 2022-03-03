local signDiskImpl = {}
local signDiskCtrl = require("sign_disk.sign_disk_ctrl")

--获取界面信息
function signDiskImpl.getInfo(roleId)
	local result = signDiskCtrl.getInfo(roleId)
	return SystemError.success, result
end

--签到抽奖
function signDiskImpl.signDraw(roleId)
	local ec,awardIndex = signDiskCtrl.signDraw(roleId)
	if ec ~= SystemError.success then 
		return ec
	end
	return SystemError.success, awardIndex
end

--领取累计奖励
function signDiskImpl.getTotalSignAward(roleId, index)
	local ec = signDiskCtrl.getTotalSignAward(roleId, index)
	return ec
end

return signDiskImpl