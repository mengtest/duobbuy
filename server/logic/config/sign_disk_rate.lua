local signDiskRate = {
	totalWeight = 0,
	data = {}
}

local signDiskConfig = require("config.sign_disk")

local totalWeight = 0
local data = {}
for index,conf in ipairs(signDiskConfig) do
	if conf.weight > 0 then
		totalWeight = totalWeight + conf.weight
		conf.weight = totalWeight
		data[index] = conf
	end
end

signDiskRate.totalWeight = totalWeight
signDiskRate.data = data

return signDiskRate