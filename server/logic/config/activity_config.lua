--[[
	类型, 页签, 排序, 名字, 标题, 内容, 开始时间, 截止时间, 持续时间, 间隔时间, 附加参数
	id, tab, rank, viewName, title, content, beginTime, endTime, lastTime, spaceTime, params
]]
local activity_config = {
 {
		id = 1,
		tab = 0,
		rank = 1,
		viewName = [[activity_recharge_disk]],
		title = [[充值转盘活动]],
		content = [[活动内容:活动期间充值可获得抽奖次数,多充多送.<br /><font color=#0000ff>尊贵专属:大力神(最高炮倍10000)</font>]],
		beginTime = 1467993600,
		endTime = 1468684799,
		lastTime = 604800,
		spaceTime = 604800,
		params = {config = "recharge_disk_config"},
	},
 {
		id = 2,
		tab = 2,
		rank = 7,
		viewName = [[activity_bag]],
		title = [[金币福袋送不停]],
		content = [[[活动时间]:<font color=#1cea00>{date}</font><br />[活动内容]:四月好福利,福袋送不停!福袋惊喜绝对亮瞎你的眼睛,快点击参与福袋活动吧!购买金币福袋就有送,最高比例赠送<font color=#1cea00>10%</font>!]],
		beginTime = 1460044800,
		endTime = 1461340799,
		lastTime = 0,
		spaceTime = 0,
		params = {},
	},
 {
		id = 3,
		tab = 2,
		rank = 8,
		viewName = [[activity_fruit]],
		title = [[找刺激]],
		content = [[[活动时间]:<font color=#1cea00>{date}</font><br />[活动内容]:活动期间，累计充值每满50元即可获得获得一次找刺激机会。最高可获得50张夺宝卡。<br />心动不如行动，赶紧去转起来！]],
		beginTime = 1460044800,
		endTime = 1461340799,
		lastTime = 0,
		spaceTime = 0,
		params = {},
	},
 {
		id = 4,
		tab = 2,
		rank = 9,
		viewName = [[activity_red_packets]],
		title = [[红包福利来袭]],
		content = [[[活动时间]:<font color=#1cea00>{date}</font><br />[活动内容]:我的天,金币没有啦!怎么办?不要怕,每天<font color=#1cea00>11:00-13:00</font>和<font color=#1cea00>17:00-18:00</font>,一大波红包疯狂来袭!<br />单次最高可抢<font color=#1cea00>20000金币</font>,每次会刷出30个红包,先抢先得,每波红包间隔10分钟,每日可抢18波红包哦!<br />心动不如行动,快来蹲点抢红包啦!Iphone,金条统统都有!]],
		beginTime = 1460044800,
		endTime = 1462118399,
		lastTime = 0,
		spaceTime = 0,
		params = {},
	},
 {
		id = 5,
		tab = 1,
		rank = 18,
		viewName = [[activity_bind_phone]],
		title = [[绑定手机送大礼]],
		content = [[[活动内容]:为了您的账号安全请前往绑定手机并设置密码，绑定后手机号码可以作为游戏账号登录游戏。系统将赠送<font color=#1cea00>5000金币</font>作为奖励。祝您游戏愉快！]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {award = {goodsId = 1,amount = 5000},checkType = "phone"},
	},
 {
		id = 6,
		tab = 2,
		rank = 3,
		viewName = [[activity_day_share]],
		title = [[天天分享赚金币]],
		content = [[[活动内容]:绑定手机后,将游戏分享至朋友圈,每日首次分享可获得<font color=#1cea00>2000金币</font>奖励,天天分享赚金币,就是这么任性!]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {award = {goodsId = 1,amount = 2000},checkType = "share"},
	},
 {
		id = 7,
		tab = 2,
		rank = 5,
		viewName = [[activity_boss]],
		title = [[奖品来袭]],
		content = [[[活动时间]:<font color=#1cea00>每天12:00—13:00、21:00—22:00</font><br />[活动内容]:活动期间,会刷出奖品,奖品全服同步,捕获后可以直接获得奖品,话费卡、京东卡、金条、iPhone等丰厚奖品等你来拿!]],
		beginTime = 1462032000,
		endTime = 1462032000,
		lastTime = 0,
		spaceTime = 0,
		params = {time = {{720,780},{1260,1320}},checkType = "prize"},
	},
 {
		id = 8,
		tab = 2,
		rank = 2,
		viewName = [[activity_arena]],
		title = [[竞技场排行]],
		content = [[[活动内容]:参加竞技场可获得积分,每日积分和每周积分排名靠前的玩家可获得丰厚奖励,<font color=#1cea00>京东卡、金币</font>奖励等你<br />来拿!]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {checkType = "arena"},
	},
 {
		id = 9,
		tab = 1,
		rank = 12,
		viewName = [[welfare_daily_task]],
		title = [[每日任务]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {config = "daily_task",award = {gunId = 5,time = 3600},name = "金刚怒吼(1小时)"},
	},
 {
		id = 10,
		tab = 1,
		rank = 11,
		viewName = [[activity_qb_sign]],
		title = [[兑换券签到]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {checkType = "prize"},
	},
 {
		id = 11,
		tab = 0,
		rank = 13,
		viewName = [[activity_lucky_bag]],
		title = [[幸运福袋]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {config = "lucky_bag_config"},
	},
 {
		id = 12,
		tab = 1,
		rank = 10,
		viewName = [[activity_sign_disk]],
		title = [[每日签到]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {},
	},
 {
		id = 13,
		tab = 0,
		rank = 14,
		viewName = [[activity_wish_well]],
		title = [[许愿池]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {config = "wish_well_config"},
	},
 {
		id = 14,
		tab = 0,
		rank = 15,
		viewName = [[activity_treasure]],
		title = [[聚宝盆]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {config = "treasure_config",award = {gunId = 11},name = "狂暴修罗"},
	},
 {
		id = 15,
		tab = 0,
		rank = 16,
		viewName = [[activity_lottery]],
		title = [[幸运寻宝]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {config = "lottery_config"},
	},
 {
		id = 16,
		tab = 0,
		rank = 17,
		viewName = [[activity_coupon]],
		title = [[开心刮刮乐]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {config = "coupon_config"},
	},
 {
		id = 17,
		tab = 1,
		rank = 19,
		viewName = [[activity_wechat]],
		title = [[微信关注]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {},
	},
 {
		id = 18,
		tab = 0,
		rank = 20,
		viewName = [[activity_crazy]],
		title = [[疯狂宝箱]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {config = "crazy_config"},
	},
 {
		id = 19,
		tab = 0,
		rank = 21,
		viewName = [[activity_bless]],
		title = [[幸运祈福]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {config = "bless_config"},
	},
 {
		id = 20,
		tab = 0,
		rank = 22,
		viewName = [[activity_weixin]],
		title = [[关注微信]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {},
	},
 {
		id = 21,
		tab = 0,
		rank = 23,
		viewName = [[activity_invite]],
		title = [[邀请好友]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {config = "invite_config"},
	},
 {
		id = 22,
		tab = 0,
		rank = 24,
		viewName = [[activity_everyday_recharge]],
		title = [[每日充值]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {},
	},
 {
		id = 23,
		tab = 0,
		rank = 25,
		viewName = [[activity_score_lottery]],
		title = [[积分抽奖]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {},
	},
 {
		id = 24,
		tab = 0,
		rank = 26,
		viewName = [[activity_money_tree]],
		title = [[摇钱树]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {config = "money_tree_config"},
	},
 {
		id = 25,
		tab = 0,
		rank = 27,
		viewName = [[activity_treasure_palace]],
		title = [[龙宫宝藏]],
		content = [[]],
		beginTime = 0,
		endTime = 0,
		lastTime = 0,
		spaceTime = 0,
		params = {},
	},
 {
		id = 29,
		tab = 2,
		rank = 9,
		viewName = [[activity_siren]],
		title = [[端午活动]],
		content = [[[活动时间]:<font color=#1cea00>{date}</font><br />[活动内容]:活动期间，渔场增加人鱼海妖，2-3分钟刷新一次，人鱼海妖基础倍率200倍，每被击中5000金币，倍率+5，最高可叠加至1000倍。]],
		beginTime = 1460044800,
		endTime = 1462118399,
		lastTime = 0,
		spaceTime = 0,
		params = {},
	},
}
return activity_config