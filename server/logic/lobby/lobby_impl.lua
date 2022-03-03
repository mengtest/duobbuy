local logger = require("log")
local skynet = require("skynet")
local context = require("common.context")

local lobbyImpl = {}

function lobbyImpl.getLobbyInfo(roleId)
	local classicsRoomPlayer = context.callS2S(SERVICE.CATCH_FISH, "getClassicsRoomPlayer")
	-- dump(getClassicsRoomPlayer)
	return SystemError.success, {classicsRoomPlayer = classicsRoomPlayer}
end

return lobbyImpl