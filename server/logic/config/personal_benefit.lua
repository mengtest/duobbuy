local personal_benefit = {}

local private_benefit = require("config.private_benefit")

for _, item in ipairs(private_benefit) do
	local items = personal_benefit[item.group]
	if not items then
		items = {}
		personal_benefit[item.group] = items
	end
	items[#items + 1] = item
end

return personal_benefit