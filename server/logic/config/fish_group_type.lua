local fish_group_type = {}

local fishGroup = require("config.fish_group")

for k, v in pairs(fishGroup) do
	local groups = fish_group_type[v.type]
	if not groups then
		groups = {}
		fish_group_type[v.type] = groups
	end
	groups[#groups + 1] = k
end

return fish_group_type