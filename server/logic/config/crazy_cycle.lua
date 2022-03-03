local crazyCycle = {}
local crazyConf = require("config.crazy_config")
local crazyRechargeConf = require("config.crazy_recharge")

local crazyBoxCycle = {}
for i,v in ipairs(crazyConf) do
	if not crazyBoxCycle[v.cycle] then
		crazyBoxCycle[v.cycle] = {}
	end
	crazyBoxCycle[v.cycle][v.id] = v
end

local crazyRechargeCycle = {}
for i,v in ipairs(crazyRechargeConf) do
	if not crazyRechargeCycle[v.cycle] then
		crazyRechargeCycle[v.cycle] = {}
	end
	crazyRechargeCycle[v.cycle][v.id] = v
end

crazyCycle.crazyBoxCycle = crazyBoxCycle
crazyCycle.crazyRechargeCycle = crazyRechargeCycle

return crazyCycle