local lotteryRate = {
}
local conf = require("config.lottery_config")

local data = {}
local weight = 0
for i,v in ipairs(conf) do
	if v.weight > 0 then
		weight = weight + v.weight
		v.weight = weight
		data[i] = v
	end
end

lotteryRate.total = weight
lotteryRate.data = data

return lotteryRate