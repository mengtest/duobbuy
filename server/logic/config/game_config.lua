local common_config = require("config.common_config")
local game_config = {	
}

-- 通过日期获取秒 yyyy-MM-dd HH:mm:ss
function getTimeByDate(r)
	require("functions")
    local a = string.split(r, " ")
    local b = string.split(a[1], "-")
    local c = string.split(a[2], ":")
    local t = os.time({year=b[1],month=b[2],day=b[3], hour=c[1], min=c[2], sec=c[3]})
    return t
end

-- 开服时间
local openTime = 0
if openTime == 0 then
	local skynet = require("skynet")
    local openDate = skynet.getenv("openDate")
    openTime = getTimeByDate(openDate)
end
common_config["serverOpenTime"] = {value = openTime}

for key,value in pairs(common_config) do
    game_config[key] = value.value
end
return game_config