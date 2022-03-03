local roleEvent = {}
local loadOverEvents = {}
local resChangeEvents = {}
local chargeEvents = {}

-- 注册客户端加载完成后的事物
function roleEvent.registerLoadOverEvent(event)
	loadOverEvents[#loadOverEvents+1] = event
end

-- 客户端加载完成事件
function roleEvent.dispathLoadOverEvent(roleId)
	if loadOverEvents then
		for index, event in pairs(loadOverEvents) do
			event(roleId)
			loadOverEvents[index] = nil
		end
	end
end

-- 注册资源变化事件
function roleEvent.registerResChangeEvent(event)
	resChangeEvents[#resChangeEvents+1] = event
end

-- 资源变化
function roleEvent.dispathResChangeEvent(roleId, ...)
	if resChangeEvents then
		for index, event in pairs(resChangeEvents) do
			event(roleId, ...)
		end
	end
end

function roleEvent.registerChargeEvent(event)
	chargeEvents[#chargeEvents+1] = event
end

function roleEvent.dispathChargeEvent(roleId, ...)
	if chargeEvents then
		for index, event in pairs(chargeEvents) do
			event(roleId, ...)
		end
	end
end

return roleEvent