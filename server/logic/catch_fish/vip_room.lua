local Room = require("catch_fish.room")

local VipRoom = class("VipRoom", Room)

function VipRoom:ctor(params)
	VipRoom.super.ctor(self, params)
	self._password = params.password
	self._minGunLevel = params.minGunLevel
end

function VipRoom:isVip()
	return true
end

function VipRoom:needPassword()
	return self._password and self._password ~= ""
end

function VipRoom:getPassword()
	return self._password
end

function VipRoom:getMinGunLevel()
	return self._minGunLevel
end

function VipRoom:getVipRoomInfo()
	local roomInfo = {
		roomId = self._roomId,
		hasPassword = self._password and #self._password > 0,
		minGunLevel = self._minGunLevel,
	}

	local players = {}
	for _, playerInfo in pairs(self._players) do
		players[#players + 1] = self:_getVipPlayerInfo(playerInfo)
	end
	roomInfo.players = players

	return roomInfo
end

function VipRoom:getRoomInfo()
	local info = VipRoom.super.getRoomInfo(self)
	info.minGunLevel = self._minGunLevel
	return info
end

function VipRoom:addPlayer(playerInfo)
	playerInfo.gunLevel = math.max(playerInfo.gunLevel, self._minGunLevel)
	return VipRoom.super.addPlayer(self, playerInfo)
end

function VipRoom:fire(fireInfo, cost)
	local playerInfo  = self._players[fireInfo.roleId]
	if playerInfo.gunLevel < self._minGunLevel then
		return CatchFishError.gunLevelTooLow
	end
	return VipRoom.super.fire(self, fireInfo, cost)
end

function VipRoom:updateGun(gunInfo)
	local playerInfo = self._players[gunInfo.roleId]
	if gunInfo.gunLevel < self._minGunLevel then
		return CatchFishError.lessThenMinGunLevel
	end
	return VipRoom.super.updateGun(self, gunInfo)
end

function VipRoom:_getVipPlayerInfo(info)
	return {
		roleId = info.roleId,
		pos = info.pos,
		avatar = info.avatar,
	}
end

return VipRoom