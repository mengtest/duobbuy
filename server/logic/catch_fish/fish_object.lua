local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt
local atan2 = math.atan2
local deg = math.deg
local rad = math.rad

local Bezier = require("bezier")
local pathCache = require("catch_fish.path_cache")

local CatchFishConst = require("catch_fish.catch_fish_const")
local FishType = CatchFishConst.FishType

local FishPathConf = require("config.fish_path")
local FishConf = require("config.fish")

local RES_ROTATION = 270

local FishObject = class("FishObject")

function FishObject:ctor(params)
	self._objectId = params.objectId
	self._type = params.type
	self._pathId = params.pathId
	self._bornX = params.bornX or 0
	self._bornY = params.bornY or 0
	self._rotation = params.rotation or 0
	self._bornTime = params.bornTime 	--出生时间点, 相对于房间创建时间点
	self._aliveTime = params.aliveTime
	self._children = params.children
	self._fixGoldDrop = params.fixGoldDrop
	self._isDead = false

	self._pathConf = FishPathConf[self._pathId]
	self._fishConf = FishConf[self._type]

	self:_createPath()
end

function FishObject:destroy()
	self._objectId = nil
	self._type = nil
	self._pathId = nil
	self._bornX = nil
	self._bornY = nil
	self._rotation = nil
	self._bornTime = nil
	self._aliveTime = nil
	self._children = nil
	self._isDead = nil
	self._pathConf = nil
	self._fishConf = nil

	self._paths = nil
end

function FishObject:getObjectId()
	return self._objectId
end

function FishObject:getType()
	return self._type
end

function FishObject:isAdd()
	return self._fishConf.isAdd == 1
end

function FishObject:getName()
	return self._fishConf.name
end

function FishObject:getChildren()
	return self._children
end

function FishObject:getZOrder()
	return self._fishConf.zorder
end

function FishObject:getX()
	return self._x
end

function FishObject:getY()
	return self._y
end

function FishObject:getMoveOutTimeLen()
	local total = 0
	for _, path in pairs(self._paths) do
		total = total + path:getTimeLen()
	end
	return total
end

function FishObject:getSendMarquee()
	return self._fishConf.sendMarquee
end

function FishObject:getNormalRatio()
	if self:getType() == FishType.GOLD_FISH then 
		return 1 / self:getGoldDrop() * 0.96
	end 
	return self._fishConf.normalRate / 1000000
end

function FishObject:getCaughtGoldDrop()
	if self._children and #self._children > 0 then
		local goldDrop = 0
		for _, fishType in ipairs(self._children) do
			local conf = FishConf[fishType]
			goldDrop = goldDrop + conf.goldDrop
		end
		return goldDrop
	elseif self._type == FishType.LOCAL_BOMB 
		or self._type == FishType.GLOBAL_BOMB then
		return 0
	else
		-- return self._fishConf.goldDrop
		return self:getGoldDrop()
	end
end


function FishObject:addBulletGold(gold)
	self._bulletGold = (self._bulletGold or 0) + gold
	-- print("self._bulletGold:"..self._bulletGold)
end

function FishObject:getBulletDrop()
	return self._bulletDrop or 0
end

function FishObject:getTimeDrop()
	return self._timeDrop or 0
end

function FishObject:updateGoldDrop()
	if self._bulletGold and self._fishConf.bulletDrop and not table.empty(self._fishConf.bulletDrop) then 
		if self._bulletGold >= self._fishConf.bulletDrop[1] then 
			local addDrop = math.floor(self._bulletGold / self._fishConf.bulletDrop[1]) * self._fishConf.bulletDrop[2]
			self._bulletDrop = (self._bulletDrop or 0) + math.min(addDrop, (self._fishConf.bulletDrop[3] or addDrop))
			self._bulletGold = self._bulletGold % self._fishConf.bulletDrop[1]
		end 
	end 
	
	if self._fishConf.timeDrop and not table.empty(self._fishConf.timeDrop) then 
		self._goldTime = (self._goldTime or 0) + 1
		if self._goldTime > self._fishConf.timeDrop[1] then 
			self._goldTime = self._goldTime - self._fishConf.timeDrop[1]
			self._timeDrop = (self._timeDrop or 0) + self._fishConf.timeDrop[2]
		end
	end 
end 

function FishObject:getGoldDrop()
	local goldDrop = self._fixGoldDrop or self._fishConf.goldDrop
	goldDrop = goldDrop + self:getTimeDrop() + self:getBulletDrop()
	if self._fishConf.maxDrop > 0 and goldDrop > self._fishConf.maxDrop then 
		goldDrop = self._fishConf.maxDrop
	end
	return goldDrop
end


function FishObject:getTreasureDrop()
	local ratio = self._fishConf.treasureDrop
	if self._children and #self._children > 0 then
		for _, fishType in ipairs(self._children) do
			local conf = FishConf[fishType]
			ratio = ratio + conf.treasureDrop
		end
	end
	return ratio
end

function FishObject:getBenefitGroup()
	return self._fishConf.benefitGroup
end

function FishObject:getWidth()
	return self._fishConf.boundingBox[1]
end

function FishObject:getHeight()
	return self._fishConf.boundingBox[2]
end

function FishObject:getAutoFirePrority()
	return self._fishConf.autoFirePrority
end

function FishObject:getInfo()
	return {
		objectId = self._objectId,
		type = self._type,
		pathId = self._pathId,
		bornX = self._bornX,
		bornX = self._bornY,
		rotation = self._rotation,
		bornTime = self._bornTime * 100,
		children = self._children,
		goldDrop = self:getGoldDrop()
	}
end

function FishObject:isBoss()
	return false
end

function FishObject:isBorned()
	return self._aliveTime > 0
end

function FishObject:isMovedOut()
	return self._isMovedOut
end

function FishObject:setDead()
	self._isDead = true
end

function FishObject:isDead()
	return self._isDead
end

function FishObject:getWidth()
	return self._fishConf.boundingBox[1]
end

function FishObject:getHeight()
	return self._fishConf.boundingBox[2]
end

function FishObject:checkCollison(currX, currY)
	local x, y, w, h = self:getX(), self:getY(), self:getWidth(), self:getHeight()
	local dx, dy = currX - x, currY - y
	local distance = sqrt(dx * dx + dy * dy)
	local angle = atan2(-dy, dx)
	local tx = distance * cos(angle + self._angle - rad(RES_ROTATION))
	local ty = -distance * sin(angle + self._angle - rad(RES_ROTATION))
	if tx >= -w/2 and tx <= w/2 
		and ty >= -h/2 and ty <= h/2 then
		return true
	end
end

function FishObject:freeze(timelen)
	-- self._bornTime = self._bornTime + timelen
end

function FishObject:update(dt)
	self._aliveTime = self._aliveTime + dt
	if not self:isBorned() then
		return
	end

	local path = self._paths[self._curPathIndex]
	while path do
		if self._aliveTime < self._curPathStartTime + path:getTimeLen() then
			break
		end
		self._curPathStartTime = self._curPathStartTime + path:getTimeLen()
		self._curPathIndex = self._curPathIndex + 1
		path = self._paths[self._curPathIndex]
	end

	if not path then
		self._isMovedOut = true
		return
	end

	local p02 = path:getPoint(self._aliveTime - self._curPathStartTime, true)
	p02 = self:_transform(p02)
	self._x = p02.x
	self._y = p02.y
end

function FishObject:_transform(p)
	--旋转、偏移
	if self._rotation ~= 0 then
		local dx, dy = p.x - self._startX, p.y - self._startY
		p.x = self._startX + dx * cos(self._rotation) + dy * sin(self._rotation)
		p.y = self._startY + dy * cos(self._rotation) - dx * sin(self._rotation)
	end
	p.x = p.x + self._bornX
	p.y = p.y + self._bornY
	return p
end

function FishObject:_createPath()
	self._startX, self._startY = self._pathConf.path[1][1], self._pathConf.path[1][2]
	self._paths = pathCache:getPathObject(self._pathId)
	if not self._paths then
		self._paths = {}
		pathCache:setPathObject(self._pathId, self._paths)
		for index, info in ipairs(self._pathConf.path) do
			local points = {}
			if index == 1 then
				points[1] = {x = info[1], y = info[2]}
				points[2] = {x = info[3], y = info[4]}
				points[3] = {x = info[5], y = info[6]}
			else
				local prev = self._pathConf.path[index - 1]
				points[1] = {x = prev[#prev - 1], y = prev[#prev]}
				points[2] = {x = info[1], y = info[2]}
				points[3] = {x = info[3], y = info[4]}
			end
			
			self._paths[#self._paths + 1] = Bezier.new(points, info.time, true)
		end
	end
	self._curPathIndex = 1
	self._curPathStartTime = 0
	self._x = 0
	self._y = 0
end

return FishObject
