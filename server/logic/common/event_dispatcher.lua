local context = require("common.context")
local dispatcher = class("dispatcher")

local DEFAULT_TAG = "__default_tag__"

function dispatcher:ctor()
	self._listeners = {}	--注册了的监听器
end

-- 注册监听函数
-- @param event 		事件ID
-- @param owner 		监听器所有者
-- @param listener 		监听函数
-- @param tag 			监听函数标签名（可选）
function dispatcher:addEventListener(event, owner, listener, tag)
	if not self._listeners[event] then
		self._listeners[event] = {}
	end

	local l = {
		owner = owner,
		listener = listener,
		tag = tag,
	}

	if tag then
		self._listeners[event][tag] = l
	end

	self._listeners[event][l] = tag or DEFAULT_TAG
end

function dispatcher:dispatchEvent(event, ...)
	if self._listeners[event] then
		for l, _ in pairs(self._listeners[event]) do
			if type(l) ~= "string" then
				if l.owner then
					l.listener(l.owner, event, ...)
				else
					l.listener(event, ...)
				end
			end
		end
	end
end

-- function dispatcher:removeListener(event, listener)
-- 	assert(self._listeners[event], "no self._listeners of event: "..event)

-- 	local tag = self._listeners[event][listener]
-- 	if tag ~= DEFAULT_TAG then
-- 		self._listeners[event][tag] = nil
-- 	end
-- 	self._listeners[event][listener] = nil
-- end

function dispatcher:removeListenerByTag(event, tag)
	assert(self._listeners[event][tag] ~= nil, "no listner of tag: "..tag)

	local listener = self._listeners[event][tag]
	self._listeners[event][listener] = nil
	self._listeners[event][tag] = nil
end

--将事件通知到agent
function dispatcher.dispatchToAgent(roleId, event, ...)
	local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
	-- assert(agentAdress, ("玩家不在线 roleId = %s"):format(roleId))
	if agentAdress then
		return context.sendS2S(agentAdress, "dispatchEvent", event, ...)
	end
end

return dispatcher
