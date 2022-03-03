local rankCtrl = require("rank.rank_ctrl")
local rankImpl = {}

function rankImpl.getArenaDayInfo(roleId)
	local result = rankCtrl.getArenaDayInfo(roleId)
	return SystemError.success, result
end

function rankImpl.getArenaWeekInfo(roleId)
	local result = rankCtrl.getArenaWeekInfo(roleId)
	return SystemError.success, result
end

-- function rankImpl.getArenaDayAward(roleId)
-- 	return rankCtrl.getArenaDayAward(roleId)
-- end

-- function rankImpl.getArenaWeekAward(roleId)
-- 	return rankCtrl.getArenaWeekAward(roleId)
-- end

function rankImpl.getAwardInfo(roleId)
	local result = rankCtrl.getAwardInfo(roleId)
	return SystemError.success, result
end

return rankImpl