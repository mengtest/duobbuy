local relicConfig = {}

local relicConf = require("config.relic_config")

for _,v in pairs(relicConf) do
	if not relicConfig[v.level] then
		relicConfig[v.level] = {}
	end
	table.insert(relicConfig[v.level], v)
end

return relicConfig