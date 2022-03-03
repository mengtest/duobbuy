local diskGroup = {}
local diskConfig = require("config.recharge_disk_config")

for _,conf in pairs(diskConfig) do
	local groupId = conf.group
	if not diskGroup[groupId] then
		diskGroup[groupId] = { info = {}, num = 0 }
	end
	local info = diskGroup[groupId].info
	info[#info+1] = conf.id
	diskGroup[groupId].num = diskGroup[groupId].num + conf.weight
end

return diskGroup