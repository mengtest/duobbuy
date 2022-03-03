local diskRate = {
	total = 0,
	data = {},
}
local disk = require("config.disk")

local data = {}
local weight = 0
for i,v in ipairs(disk) do
	if v.weight > 0 then
		weight = weight + v.weight
		v.weight = weight
		data[i] = v
	end
end

diskRate.total = weight
diskRate.data = data

return diskRate