local arenaRankAward = {}
local arenaRankConfig = require("config.arena_rank_config")

for _,conf in pairs(arenaRankConfig) do
	if not arenaRankAward[conf.type] then
		arenaRankAward[conf.type] = {}
	end
	arenaRankAward[conf.type][conf.rank] = conf.award
end

return arenaRankAward