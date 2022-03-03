local FishObject = require("catch_fish.fish_object")
local prizeConf = require("config.prize")

local BossObject = class("BossObject", FishObject)

function BossObject:ctor(params)
	BossObject.super.ctor(self, params)
	self._prizeConf = prizeConf[params.prizeId]
end

function BossObject:getWorth()
	return self._prizeConf.worth
end

function BossObject:isBoss()
	return true
end

return BossObject
