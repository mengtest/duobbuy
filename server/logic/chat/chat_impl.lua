local chatCtrl = require("chat.chat_ctrl")

local chatImpl = {}

function chatImpl.speakToWorld(roleId, data)
	return chatCtrl.speakToWorld(roleId, data)
end

return chatImpl