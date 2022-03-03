local marqueeCtrl = {}
local dbHelp      = require("common.db_help")
local json    = require("json")
local context = require("common.context")

--获取跑马灯缓存信息
function marqueeCtrl.getMessage()
	local marqueeInfos = dbHelp.call("marquee.getmarqueeInfos")
	return marqueeInfos
	-- return {}
end

function marqueeCtrl.judgeMarqueeExist(marqueeId)
	return dbHelp.call("marquee.judgeMarqueeExist", marqueeId)
end

--增加跑马灯消息
function marqueeCtrl.addMarqueeInfo(info)
	local info = json.decode(info)
	local marqueeInfo = {
		id          =  tonumber(info.id),
		priority    =  info.priority,
		startTime   =  info.start_time,
		endTime     =  info.end_time,
		timeInterval=  info.time_interval,
		times       =  info.times,
		content     =  info.content,
	}
	dbHelp.call("marquee.addMarqueeInfo",marqueeInfo)
	context.sendS2S(SERVICE.MARQUEE, "setMessage",marqueeInfo)
end


--修改跑马灯消息
function marqueeCtrl.setMarqueeInfo(info)
	local info = json.decode(info)
	local marqueeInfo = {
		id          =  tonumber(info.id),
		priority    =  info.priority,
		startTime   =  info.start_time,
		endTime     =  info.end_time,
		timeInterval=  info.time_interval,
		times       =  info.times,
		content     =  info.content,
	}
	dbHelp.call("marquee.setMarqueeInfo",marqueeInfo)
	context.sendS2S(SERVICE.MARQUEE, "setMessage",marqueeInfo)
end


--删除跑马灯消息
function marqueeCtrl.delMarqueeInfo(marqueeId)
	marqueeId = tonumber(marqueeId)
	dbHelp.call("marquee.delMarqueeInfo",marqueeId)
	context.sendS2S(SERVICE.MARQUEE, "delMessage",marqueeId)
end

return marqueeCtrl