local fruitRate = {
	total = 0,
	data = {},
}
local fruit = require("config.fruit")

local data = {}
local weight = 0
for i,v in ipairs(fruit) do
	if v.weight > 0 then
		weight = weight + v.weight
		v.weight = weight
		data[i] = v
	end
end

fruitRate.total = weight
fruitRate.data = data

return fruitRate