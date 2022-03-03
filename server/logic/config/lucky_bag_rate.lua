local bagRate = {
	total = 0,
	data = {},
}
local bagConf = require("config.lucky_bag_config")

local data = {}
local weight = 0
for i,v in ipairs(bagConf) do
	if v.weight > 0 then
		weight = weight + v.weight
		v.weight = weight
		data[i] = v
	end
end

bagRate.total = weight
bagRate.data = data

return bagRate