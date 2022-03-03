local goldGunConf = {}

local goldGunConfig = require("config.gold_gun_config")

for _,v in pairs(goldGunConfig) do
	if not goldGunConf[v.level] then
		 goldGunConf[v.level] = {}
	end
	table.insert(goldGunConf[v.level], v)
end

return goldGunConf