local gunLevelMap = {}
local gunLevels = require("config.gun_level")

for _, item in ipairs(gunLevels) do
	local items = gunLevelMap[item.type]
	if not items then
		items = {}
		gunLevelMap[item.type] = items
	end
	items[item.level] = item.rp
end

return gunLevelMap