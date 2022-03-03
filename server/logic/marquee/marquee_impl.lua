local marqueeImpl = {}
local context     = require("common.context")

--获取跑马灯消息
function  marqueeImpl.getMessage(roleId)
	local result = {marquees = {}}
	local marquees = context.callS2S(SERVICE.MARQUEE, "getMessageOn")
	if not table.empty(marquees) then
		for _,v in pairs(marquees) do
			table.insert(result.marquees,v)
		end
	end
	return SystemError.success,result
end

return marqueeImpl