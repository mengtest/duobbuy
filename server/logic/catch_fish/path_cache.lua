local PathCache = class("PathCache")

function PathCache:ctor()
	self._pathObjs = {}
end

function PathCache:getPathObject(pathId)
	return self._pathObjs[pathId]
end

function PathCache:setPathObject(pathId, pathObj)
	self._pathObjs[pathId] = pathObj
end

return PathCache.new()