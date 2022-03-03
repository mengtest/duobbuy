--[[
	类型, 名字, 标题, 时间, 内容, 进度, 开始时间, 持续时间, 间隔时间, 附加参数
	id, viewName, title, time, content, progress, beginTime, lastTime, spaceTime, params
]]
local recharge_activity = {
 {
		id = 1,
		viewName = [[activity_daily_recharge]],
		title = [[每日充值]],
		time = [[[活动倒计时]:<font color=#00d914>%s</font>]],
		content = [[[活动内容]:每天充值达到相应额度就送金币,每天<font color=#00d914>00:00</font>重置.]],
		progress = [[今日已累计充值:<font color=#00d914>%d</font>]],
		beginTime = 1462723200,
		lastTime = 604800,
		spaceTime = 604800,
		params = {config = "daily_recharge"},
	},
 {
		id = 2,
		viewName = [[activity_cumulate_recharge]],
		title = [[累计充值]],
		time = [[[活动倒计时]:<font color=#00d914>%s</font>]],
		content = [[[活动内容]:活动期间内充值达到相应额度即可领取,多充多送.]],
		progress = [[已累计充值:<font color=#00d914>%d</font>]],
		beginTime = 1462723200,
		lastTime = 604800,
		spaceTime = 604800,
		params = {config = "cumulate_recharge"},
	},
}
return recharge_activity