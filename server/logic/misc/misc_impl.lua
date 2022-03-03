local configDb = require("config.config_db")
local MiscOnlineConfig = configDb.misc_online_config
local miscCtrl = require("misc.misc_ctrl")

local miscImpl = {}

function miscImpl.getMiscOnlineInfo(roleId)
	-- dump(miscCtrl.getMiscOnlineInfo(roleId),_,9)
	return SystemError.success, miscCtrl.getMiscOnlineInfo(roleId)
end 

function miscImpl.getMiscOnlineAward(roleId, data)
	return miscCtrl.getMiscOnlineAward(roleId, data.type, data.day)
end 

return miscImpl