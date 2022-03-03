local eggCycleConfig = {}
local eggConf = require("config.egg_config")
local eggRechargeConf = require("config.egg_recharge")

local eggCycle = {}
for i,v in ipairs(eggConf) do
	if not eggCycle[v.cycle] then
		eggCycle[v.cycle] = {}
	end
	eggCycle[v.cycle][v.id] = v
end

local eggRechargeCycle = {}
for i,v in ipairs(eggRechargeConf) do
	if not eggRechargeCycle[v.cycle] then
		eggRechargeCycle[v.cycle] = {}
	end
	eggRechargeCycle[v.cycle][v.id] = v
end

eggCycleConfig.eggCycle = eggCycle
eggCycleConfig.eggRechargeCycle = eggRechargeCycle

return eggCycleConfig