local fish_path_group = {}

local fishPath = require("config.fish_path")

for k, v in pairs(fishPath) do
	local paths = fish_path_group[v.groupId]
	if not paths then
		paths = {}
		fish_path_group[v.groupId] = paths
	end

	paths[#paths + 1] = k
end

return fish_path_group