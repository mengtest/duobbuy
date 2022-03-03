local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt
local pi = math.pi
local min = math.min

local Bullet = class("Bullet")
local logger = require("log")

local GunConf = require("config.gun")
local GunLevelMap = require("config.gun_level_map")

local DEFAULT_BOX = {x = 0, y = 0, width = 1024, height = 576}
local MAX_ALIVE_TIME = 40

function Bullet:ctor(params)
	self._type = params.type
	self._level = params.level
	self._fireTime = params.fireTime
	self._fireAngle = params.fireAngle
	self._aimFish = params.aimFish
	self._conf = GunConf[params.type]
	assert(GunLevelMap[self._type], "self._type:"..self._type.." self._level:"..self._level)
	self._rp = GunLevelMap[self._type][self._level] or 0
	self._curTime = 0

	assert(self._type)
	assert(self._level)
	assert(self._fireTime)
	assert(self._fireAngle)
	assert(self._conf)
	assert(self._rp)
	assert(self._curTime)
end

function Bullet:destroy()
	self._type = nil
	self._level = nil
	self._fireTime = nil
	self._fireAngle = nil
	self._aimFish = nil
	self._conf = nil
	self._rp = nil
	self._curTime = nil
end

function Bullet:getType()
	return self._type
end

function Bullet:getLevel()
	assert(self._level)
	return self._level
end

function Bullet:getCP()
	return self._conf.cp / 10000
end

function Bullet:getRP()
	return self._rp / 10000
end

function Bullet:getAimFish()
	return self._aimFish
end

function Bullet:getInfo()
	local info = {
		type = self:getType(),
		level = self:getLevel(),
		fireTime = self._fireTime * 100,
		fireAngle = self._fireAngle,
	}
	return info
end

function Bullet:getX()
	return self._x
end

function Bullet:getY()
	return self._y
end

function Bullet:update(dt)
	self._curTime = self._curTime + dt

	local dis = self._speed * dt
	while dis > 1 do
		local dx = dis * cos(self._curAngle)
		local dy = -dis * sin(self._curAngle)
		local turn
		if self._x + dx	<= self._box.x then
			dx = self._box.x - self._x
			turn = pi
		elseif self._x + dx >= self._box.x + self._box.width then
			dx = self._box.x + self._box.width - self._x
			turn = pi
		end

		if self._y + dy	<= self._box.y then
			dy = self._box.y - self._y
			turn = 2 * pi
		elseif self._y + dy >= self._box.y + self._box.height then
			dy = self._box.y + self._box.height - self._y
			turn = 2 * pi
		end

		dis = dis - sqrt(dx * dx + dy * dy)
		self._x = self._x + dx
		self._y = self._y + dy

		if turn then
			self._curAngle = turn - self._curAngle
			if self._curAngle < 0 then
				self._curAngle = 2 * pi + self._curAngle
			end
		end
	end
	
end

return Bullet