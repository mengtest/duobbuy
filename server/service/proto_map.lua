--协议文件列表
local protoFiles = {
	"auth.pb",
	"role.pb",
	"lobby.pb",
	"catch_fish.pb",
	"disk.pb",
	"chat.pb",
	"marquee.pb",
	"fruit.pb",
	"fund.pb",
	"misc.pb",
	"activity.pb",
	"shop.pb",
	"mobile.pb",
	"red_money.pb",
	"rank.pb",
	"boss.pb",
	"mail.pb",
	"online_award.pb",
	"task.pb",
	"lucky_bag.pb",
	"pot.pb",
	"box.pb",
	"seven_day.pb",
	"sign.pb",
	"wish_pool.pb",
	"sign_disk.pb",
	"treasure_bowl.pb",
	"coupon.pb",
	"lottery.pb",
	"bless.pb",
	"crazy_box.pb",
	"daily_charge.pb",
	"invite.pb",
	"score_lottery.pb",
	"money_tree.pb",
	"treasure_palace.pb",
	"relic.pb",
	"egg.pb",
	"gold_gun.pb",
	"morrow_gift.pb",
}

SERVICE = {
	WATCHDOG 	= "WATCHDOG",			--watchdog.lua		转发消息
	AUTH 		= "AUTH", 				--auth.lua			登陆鉴权
	AGENT 		= "AGENT",				--agent.lua			玩家实体
	MAIN_DB 	= "MAIN_DB",			--main_db.lua		负责 ID 的生成
	WORD_FILTER = "WORD_FILTER",   		--word_filter.lua	屏蔽字
	GAMELOG 	= "GAMELOG",   			--gamelog.lua		游戏日志
	DATACENTER 	= "DATACENTER", 		--datacenterd.lua	
	CHAT 		= "CHAT_SVC",			--chat_svc.lua		聊天
	CATCH_FISH 	= "CATCH_FISH",			--catch_fish.lua	捕鱼房间
	MARQUEE 	= "MARQUEE",			--marquee.lua		跑马灯
	RECORD 		= "RECORD",				--record.lua		平台接口
	MONITOR		= "PERFOR_MONITOR",		-- perfor_monitor.lua
	CHARGE 		= "CHARGE",				--charge.lua		充值
	RED_MONEY 	= "RED_MONEY",			--red_money.lua		红包玩法
	STATISTIC 	= "STATISTIC",			--statistic.lua		
	RANK 		= "RANK", 				--rank.lua			排行榜
	MAIL 		= "MAIL",				--mail_svc.lua		邮件
	PUSH 		= "PUSH",				--push.lua			
	POT 		= "POT",				--pot.lua			
	ACTIVITY 	= "ACTIVITY",			--activity.lua		活动
	MISC		= "MISC",				--misc.lua			兑换任务
	SHUTDOWN_SERVER = "SHUTDOWN_SERVER", 	-- shutdown.lua
}

PROTO_LOG = {
    NONE = 0,   --不记录
    REQUEST = 1,  --只记录请求数据
    EC = 2,        --记录请求数据和返回的错误码
    ALL = 3,        --记录全部，如果协议为事件类型，则必须填写该值才能记录
}

--请求定义列表
local protoMap = {
	protos = {},
	files = protoFiles,
}
local mt = {}
mt.__newindex = function(t, k, v)
	for key, proto in pairs(v) do
		if key ~= "module" and key ~= "service" then
			assert(t.protos[proto.id] == nil, string.format("had the same proto id[%x], name[%s]", proto.id, key))
			t.protos[proto.id] = {
				id = proto.id,
				type = proto.type,
				request = proto.request,
				response = proto.response,
				module = v.module,
				service = proto.service or v.service,
				name = key,
				fullname = v.module .. "." .. key,
				desc = proto.desc or key,
           log = proto.log or PROTO_LOG.NONE,
				}
		end
	end
end
setmetatable(protoMap, mt)

--[[格式说明
	id:协议编号,序列化为两个字节
	type：请求类型 1、客户端主动的请求, 2、服务端主动通知
	request：客户端请求是传递的消息类型，除了自定义类型外，还可以为int8、int16、int32类型,或者为空,服务端主动通知协议没有该值
	response：服务端向客户端发送的消息类型，除了自定义类型外，还可以为int8、int16、int32类型,,或者为空
]]

PROTO_TYPE = {
	C2S = 1,
	S2C = 2,
}

--游戏其他相关协议
M_Game = {
	module 				= "game",
	ping				= {id = 0x0001, type = 1, request = nil, response = "game.Timestamp"},	--返回服务端时间
}
protoMap.Game 			= M_Game

--认证模块
M_Auth = {
	module = "auth",
	service = SERVICE.AUTH,
	login 				= {id = 0x0101, type = 1, request = "auth.LoginRequest", response = "auth.LoginResponse", log = 0, desc = "登录"},
	createRole 			= {id = 0x0102, type = 1, request = "auth.CreateRoleInfo", response = nil, log = 1, desc = "创建角色"},
	heartbeat 			= {id = 0x0103, type = 1, request = nil, response = nil, log = 0, desc = "心跳"},
	onOffline			= {id = 0x0104, type = 2, response = "auth.OfflineReason", log = 1, desc = "离线"},
	getServerTime 		= {id = 0x0105, type = 1, response = "auth.ServerTime", log = 0, desc = "获取服务器时间"},
}
protoMap.Auth 			= M_Auth

-- 大厅模块
M_LOBBY = {
	module = "lobby",
	getLobbyInfo 		= {id = 0xa001, type = 1, request = nil, response = "lobby.LobbyInfo", log = 2, desc = "获得大厅信息"},
	syncLobbyInfo		= {id = 0xa0a1, type = 2, response = "lobby.LobbyInfo", log = 0, desc = "同步大厅信息"},
}
protoMap.LOBBY 			= M_LOBBY

--捕鱼模块
M_CatchFish = {
	module = "catch_fish",
	enterRoom 			= {id = 0x0201, type = 1, request = nil, response = "catch_fish.RoomInfo", log = 2, desc = "进入捕鱼房间"},
	fire 				= {id = 0x0202, type = 1, request = "catch_fish.FireInfo", response = nil, log = 0, desc = "开炮"},
	hit 				= {id = 0x0203, type = 1, request = "catch_fish.HitInfo", response = nil, log = 0, desc = "命中"},
	aim 				= {id = 0x0204, type = 1, request = "catch_fish.AimInfo", response = nil, log = 0, desc = "瞄准"},
	updateGun			= {id = 0x0205, type = 1, request = "catch_fish.UpdateGunInfo", response = nil, log = 0, desc = "更换炮"},
	getVipRoomList		= {id = 0x0206, type = 1, request = nil, response = "catch_fish.VipRoomList", log = 0, desc = "获取VIP房间列表"},
	createVipRoom		= {id = 0x0207, type = 1, request = "catch_fish.CreateVipRoomInfo", response = "catch_fish.RoomInfo", log = 2, desc = "创建VIP房间"},
	enterVipRoom		= {id = 0x0208, type = 1, request = "catch_fish.EnterVipRoomRequest", response = "catch_fish.RoomInfo", log = 2, desc = "进入VIP房间"},
	stopAim 			= {id = 0x0209, type = 1, request = nil, response = nil, log = 0, desc = "停止瞄准"},

	getArenaList 		= {id = 0x020a, type = 1, request = nil, response = "catch_fish.ArenaList", log = 0, desc = "获取竞技场信息"},
	joinArena	 		= {id = 0x020b, type = 1, request = "catch_fish.JoinRequest", response = "int32", log = 0, desc = "报名指定竞技场"},
	cancelJoinArena		= {id = 0x020c, type = 1, request = nil, response = nil, log = 0, desc = "报名指定竞技场"},
	enterArena	 		= {id = 0x020d, type = 1, request = "int32", response = "catch_fish.ArenaRoomInfo", log = 0, desc = "进入指定竞技场"},
	getArenaResults		= {id = 0x020e, type = 1, request = nil, response = "catch_fish.ArenaResultList", log = 0, desc = "获取该玩家参与过的竞技结果信息列表"},
	getDoingArena 		= {id = 0x020f, type = 1, request = nil, response = "catch_fish.DoingArenaInfo", log = 0, desc = "获取正在进行的比赛"},
	giveUpArena		 	= {id = 0x0210, type = 1, request = "int32", response = nil, log = 0, desc = "放弃竞技比赛"},
	createArena		 	= {id = 0x0212, type = 1, request = "catch_fish.CreateArenaRequest", response = "int32", log = 0, desc = "创建竞技场房间"},
	
	leaveRoom	 		= {id = 0x0211, type = 1, request = nil, response = nil, log = 0, desc = "离开"},
	freeze		 		= {id = 0x0213, type = 1, request = nil, response = nil, log = 0, desc = "冰冻"},
	crit		 		= {id = 0x0214, type = 1, request = nil, response = nil, log = 0, desc = "进入狂暴状态"},

	slice		 		= {id = 0x0218, type = 1, request = "catch_fish.SliceInfo", response = nil, log = 0, desc = "切鱼"},

	robotHit			= {id = 0x0215, type = 1, request = "catch_fish.HitInfo", log = 0, desc = "机器人命中通知信息"},	
	registerVipRoom		= {id = 0x0216, type = 1, request = nil, response = "catch_fish.VipRoomList", log = 0, desc = "获取VIP房间列表"},
	unregisterVipRoom	= {id = 0x0217, type = 1, request = nil, response = nil, log = 0, desc = "获取VIP房间列表"},
	
	handlePlayerEnter		= {id = 0x02a1, type = 2, response = "catch_fish.Player", log = 0, desc = "玩家进入房间"},
	handlePlayerLeave		= {id = 0x02a2, type = 2, response = "int32", log = 0, desc = "玩家离开房间"},
	handleFishBorn			= {id = 0x02a3, type = 2, response = "catch_fish.FishBornInfo", log = 0, desc = "鱼群进入"},
	handleFishDie			= {id = 0x02a4, type = 2, response = "catch_fish.FishDieInfo", log = 0, desc = "鱼死亡"},
	handleFire				= {id = 0x02a5, type = 2, response = "catch_fish.FireInfo", log = 0, desc = "开炮通知信息"},
	handleHit				= {id = 0x02a6, type = 2, response = "catch_fish.HitInfo", log = 0, desc = "命中通知信息"},
	handleAim				= {id = 0x02a7, type = 2, response = "catch_fish.AimInfo", log = 0, desc = "瞄准通知信息"},
	handleUpdateGun			= {id = 0x02a8, type = 2, response = "catch_fish.UpdateGunInfo", log = 0, desc = "更换炮通知信息"},
	handleDrop				= {id = 0x02a9, type = 2, response = "catch_fish.DropInfo", log = 0, desc = "掉落获得信息"},
	-- handleTotalPlayerUpdate	= {id = 0x02aa, type = 2, response = "int32", log = 0, desc = "夺宝场人数变化"},
	handleStopAim			= {id = 0x02ab, type = 2, response = "int32", log = 0, desc = "停止瞄准"},
	handleFishStrikes		= {id = 0x02ac, type = 2, response = nil, log = 0, desc = "鱼群来袭"},
	handlePlayerGoldUpdate	= {id = 0x02ad, type = 2, response = "catch_fish.UpdatePlayerGold", log = 0, desc = "其他玩家金币更新"},
	handleDropThreasure		= {id = 0x02ae, type = 2, response = "catch_fish.DropTreasure", log = 0, desc = "掉落夺宝卡"},

	handleJoinArenaInfoUpdate = {id = 0x02af, type = 2, response = "catch_fish.JoinArenaInfo", log = 0, desc = "竞技场报名信息更新"},
	handleArenaBegin		= {id = 0x02b1, type = 2, response = "int32", log = 0, desc = "竞技开始"},
	handleArenaOver			= {id = 0x02b2, type = 2, response = "catch_fish.ArenaResult", log = 0, desc = "竞技结果"},
	handlePlayerStateUpdate	= {id = 0x02b3, type = 2, response = "catch_fish.PlayerState", log = 0, desc = "玩家状态改变"},
	handleArenaGoldUpdate	= {id = 0x02b4, type = 2, response = "catch_fish.UpdatePlayerGold", log = 0, desc = "竞技场子弹数量改变"},

	handleFreeze			= {id = 0x02b5, type = 2, response = "catch_fish.FreezeInfo", log = 0, desc = "冰冻事件"},
	handleUnfreeze			= {id = 0x02b6, type = 2, response = nil, log = 0, desc = "解冻事件"},
	handleJieNeng			= {id = 0x02b7, type = 2, response = nil, log = 0, desc = "节能炮触发"},

	-- onCreateVipRoom		= {id = 0x02b8, type = 2, response = "catch_fish.VipRoomInfo", log = 0, desc = "增加 VIP 房间"},
	onUpdateVipRoom			= {id = 0x02b8, type = 2, response = "catch_fish.VipRoomInfo", log = 0, desc = "增加/更新 VIP 房间"},
	onDestroyVipRoom		= {id = 0x02b9, type = 2, response = "int32", log = 0, desc = "销毁 VIP 房间"},

	onUpFishInfo			= {id = 0x02ba, type = 2, response = "catch_fish.UpFishInfo", log = 0, desc = "更新鱼的信息"},

	onSlice		 			= {id = 0x02bb, type = 2, response = "catch_fish.SliceInfo", log = 0, desc = "同步切鱼消息"},
	onSliceFinish		 	= {id = 0x02bc, type = 2, response = nil, log = 0, desc = "切鱼结束"},
	
	handlePlayerInfoUpdate	= {id = 0x02bd, type = 2, response = "catch_fish.UpdatePlayerInfo", log = 0, desc = "更新玩家信息"},
}
protoMap.CatchFish 			= M_CatchFish

--角色模块
M_Role = {
	module = "role",
	getRoleInfo 		= {id = 0x0301, type = 1, request = nil, response = "role.RoleInfo", log = 0, desc = "获取角色信息"},
	getFreeGoldLeftSec 	= {id = 0x0302, type = 1, request = nil, response = "int32", log = 0, desc = "获取免费金币剩余时间"},
	getFreeGold 		= {id = 0x0303, type = 1, request = nil, response = "role.FreeGoldInfo", log = 2, desc = "获取免费金币"},
	changeRoleInfo 		= {id = 0x0304, type = 1, request = "role.SetInfo", log = 0, desc = "玩家修改信息"},
	saveSeting 			= {id = 0x0305, type = 1, request = "role.String", log = 0, desc = "前端保存数据"},
	getSeting			= {id = 0x0306, type = 1, response = "role.String", log = 0, desc = "获取前端保存数据"},
	shopTest 			= {id = 0x0307, type = 1, request = "int32", log = 2, desc = "商城购买测试"},
	getFirstChargeInfo  = {id = 0x0308, type = 1, response = "int32", log = 0, desc = "获取首冲状态"},
	loadOver 			= {id = 0x0309, type = 1, log = 0, desc = "界面加载完成"},
	getFundJoinsStatus  = {id = 0x030a, type = 1, response = "role.Bool", log = 0, desc = "获取是否参与夺宝"},
	useGoldEnergy 		= {id = 0x030b, type = 1, response = nil, log = 2, desc = "炮能量兑换夺宝卡"},
	getChangeBagStatus 	= {id = 0x030c, type = 1, request = "int32", response = "role.Bool", log = 0, desc = "获取玩家是否有奖励"},
	getChangeBagAward 	= {id = 0x030d, type = 1, request = "int32", log = 2, desc = "获取换包奖励"},
	getReturnStatus		= {id = 0x030e, type = 1, response = "int32", log = 0, desc = "获取回锅奖励信息"},	--返回奖励序号 0 无奖励
	getReturnAward		= {id = 0x030f, type = 1, log = 2, desc = "获取回归奖励"},
	getWeChatFollowStatus = {id = 0x0311, type = 1, response = "int32", log = 2, desc = "获取微信关注状态"},
	setWeChatFollowStatus = {id = 0x0312, type = 1, log = 2, desc = "设置微信关注状态"},

	handleGoldUpdate		= {id = 0x03a1, type = 2, response = "int32", log = 0, desc = "金币数量更新"},
	handleTreasureUpdate 	= {id = 0x03a2, type = 2, response = "int32", log = 0, desc = "夺宝卡数量更新"},
	handleChargeSuccess 	= {id = 0x03a3, type = 2, response = "role.ChargeInfo", log = 0, desc = "充值成功"},
	handleGetGoldGun 		= {id = 0x03a4, type = 2, log = 0, desc = "获得黄金炮"},
	handleChargeNumUpdate 	= {id = 0x03a5, type = 2, response = "int32", log = 0, desc = "充值金额变化"},
	handleActivityGunEnd 	= {id = 0x03a6, type = 2, response = "int32", log = 0, desc = "活动炮塔过期"},
	handleGetActivityGun 	= {id = 0x03a7, type = 2, response = "role.endGunUpdateInfo", log = 0, desc = "获得活动炮塔"},
	handleDayChange 		= {id = 0x03a8, type = 2, log = 0, desc = "换天提送"},
	handlePrizeUpdate 		= {id = 0x03a9, type = 2, response = "int32", log = 0, desc = "彩金更新"},
	handleExpInfoUpdate		= {id = 0x03aa, type = 2, response = "role.RoleExpInfo", log = 0, desc = "玩家等级经验变化"},
}
protoMap.Role 			= M_Role

--转盘
M_Disk = {
	module = "disk",
	roll 				= {id = 0x0401, type = 1, response = "disk.LuckyInfo", log = 0, desc = "转转盘"},
	canRoll 			= {id = 0x0402, type = 1, response = nil, log = 0, desc = "能否转转盘"},
}
protoMap.Disk 			= M_Disk

--跑马灯
M_Marquee = {
	module 				 = "marquee",
	getMessage 	         = {id = 0x0501, type = 1, request = nil, response = "marquee.MarqueeInfos", log = 0}, --登录获取系统消息
	handleSendMsgByKeyWord   = {id = 0x05a1, type = 2, request = nil, response = "marquee.MarqueeKeyWord", log = 0}, --主推游戏内消息
	handleSendMsgBySentence  = {id = 0x05a2, type = 2, request = nil, response = "marquee.MarqueeInfo", log = 0}, --主推系统消息
	handleAltMsg             = {id = 0x05a3, type = 2, request = nil, response = "marquee.MarqueeInfo", log = 0}, --主推系统消息变动
	handleDelMsg             = {id = 0x05a4, type = 2, request = nil, response = "int32", log = 0}, --主推系统消息变动
}
protoMap.Marquee	 	 = M_Marquee

--聊天模块
M_Chat = {
	module 				= "chat",
	speakToWorld		= {id = 0x0601, type = 1, request = "chat.MessageInfo", response = nil, log = 0, desc = "房间聊天"},
	handleSpeakToWorld		= {id = 0x06a1, type = 2, request = nil, response = "chat.MessageInfo", log = 0, desc = "推送房间聊天消息"},
}
protoMap.Chat 			= M_Chat

--开宝箱
M_Box = {
	module 				= "box",
	open 				= {id = 0x0701, type = 1, request = "int32", response = "int32", log = 2, desc = "开宝箱"},
	getInfo 			= {id = 0x0702, type = 1, response = "box.Info", log = 0, desc = "获取开奖次数"},
}
protoMap.Box 			= M_Box

--找刺激
M_Fruit = {
	module 				= "fruit",
	getInfo 			= {id = 0x0801, type = 1, response = "int32", log = 0, desc = "获取水果机信息"},
	roll 				= {id = 0x0802, type = 1, response = "fruit.LuckyInfo", log = 2, desc = "水果机抽奖"},
} 
protoMap.Fruit 			= M_Fruit

--夺宝
M_Fund = {
	module				= "fund",
	join 				= {id = 0x0901, type = 1, request = "fund.JoinInfo", response = "int32", log = 2, desc = "参加夺宝"},
	exchange 			= {id = 0x0902, type = 1, request = "int32", log = 2, desc = "兑换商城物品"},
	readFundRecord 		= {id = 0x0903, type = 1, request = "int32", log = 2, desc = "读取夺宝记录"},

	onFirstFund         = {id = 0x09a1, type = 2, log = 2, desc = "第一次中奖推送"},
	onSyncFundRecord    = {id = 0x09a2, type = 2, response = "fund.RecordInfoList", log = 2, desc = "推送新的夺宝记录"},
	-- onJoinWinning    	= {id = 0x09a3, type = 2, response = "fund.WinningInfo", log = 2, desc = "夺宝中奖"},
}
protoMap.Fund 			= M_Fund

-- 礼包码
M_Misc = {
	module              = "misc",
	-- useMiscCode			= {id = 0x0a01, type = 1, request = "misc.miscCode", response = "misc.miscGoods", log = 2, desc = "使用兑换码"}, --使用兑换码
	getMiscOnlineInfo	= {id = 0x0a02, type = 1, request = nil, response = "misc.MiscOnlineList", log = 2, desc = "获得兑换码在线任务"}, --获得兑换码在线任务
	getMiscOnlineAward	= {id = 0x0a03, type = 1, request = "misc.AwardRequest", response = "misc.MiscOnlineAward", log = 2, desc = "兑换码在线任务奖励"}, --兑换码在线任务奖励

	-- handleGetMisc       = {id = 0x0aa1, type = 2, request = nil, response = "misc.miscInfo"}, --通知领取礼包
}
protoMap.Misc 		 	= M_Misc

-- 充值转盘活动
M_Activity = {
	module				= "activity",
	getRollInfo 		= {id = 0x0b01, type = 1, response = "activity.diskInfo", log = 0, desc = "获取转盘信息"}, --获取转盘次数
	rollDisk 			= {id = 0x0b02, type = 1, response = "int32", log = 2, desc = "转转盘"}, --转转盘
	shareSuccess 		= {id = 0x0b03, type = 1, response = "activity.award", log = 2, desc = "分享成功"}, 	--分享成功获得金币
	getDailyRechargeInfo = {id = 0x0b04, type = 1, response = "activity.rechargeInfo", log = 0, desc = "获取每日累积充值活动信息"},
	getDailyRechargeAward = {id = 0x0b05, type = 1, request = "int32", log = 2, desc = "领取每日累积充值活动奖励"},
	getRoundRechargeInfo = {id = 0x0b06, type = 1, response = "activity.rechargeInfo", log = 0, desc = "获取一期累积充值活动信息"},
	getRoundRechargeAward = {id = 0x0b07, type = 1, request = "int32", log = 2, desc = "领取每日累积充值活动奖励"},
	getActivityTime 	= {id = 0x0b08, type = 1, response = "activity.timeInfo", log = 0, desc = "获取活动开启时间信息"},
	handleDaySendAward 		= {id = 0x0ba1, type = 2, log = 0, desc = "自动发送每日奖励"},
	handleRoundSendAward 	= {id = 0x0ba2, type = 2, log = 0, desc = "自动发送没轮奖励"},
	handleRollInfoUpdate 	= {id = 0x0ba3, type = 2, response = "activity.diskInfo", log = 0, desc = "装盘信息变更"},
	handleActivityTimeUpdate = {id = 0x0ba4, type = 2, response = "activity.activityInfo", log = 0, desc = "活动时间变化"},
}
protoMap.Activity 		= M_Activity

-- 商城
M_Shop = {
	module 				= "shop",
	getGiftShopInfo 	= {id = 0x0c01, type = 1, response = "shop.ShopInfos", log = 0, desc = "获取超值商城"}, -- 获取超值商城状态
	getMonthCardDays    = {id = 0x0c02, type = 1, response = "int32", log = 0, desc = "获取月卡剩余天数"}, -- 获取月卡剩余天数
	getGiftInfoList    	= {id = 0x0c03, type = 1, request = "int32", response = "shop.GiftInfoList", log = 0, desc = "获取礼包剩余天数"}, -- 获取礼包剩余天数
}
protoMap.Shop 			= M_Shop

-- 手机号码绑定
M_Mobile = {
	module 				= "mobile",
	sendActiveCode 		= {id = 0x0d01, type = 1, request = "mobile.Info", log = 0, desc = "发送手机验证码"},	 --发送手机验证码
	checkActiveCode 	= {id = 0x0d02, type = 1, request = "mobile.Info", log = 0, desc = "验证手机验证码"},	 --验证手机验证码
}
protoMap.Mobile 		= M_Mobile

-- 红包
M_RedMoney = {
	module 				= "red_money",
	openBag 			= {id = 0x0e01, type = 1, response = "red_money.bagInfo", log = 2, desc = "玩家抢红包"}, --枪红包
	getActivityStatus 	= {id = 0x0e02, type = 1, response = "int32", log = 0, desc = "获取活动是否进行中"},
	handleStart 			= {id = 0x0ea1, type = 2, log = 0, desc = "抢红包活动开始"},
	handleEnd 				= {id = 0x0ea2, type = 2, log = 0, desc = "抢红包活动结束"},
	handleMoneySend 		= {id = 0x0ea3, type = 2, log = 0, desc = "系统红包发放"},
}
protoMap.RedMoney 		= M_RedMoney

-- 红点
M_RedPoint = {
	module 				= "red_point",
	handleActive 			= {id = 0x0f01, type = 2, response = "role.String", log = 0, desc = "红点激活"},
}
protoMap.RedPoint 		= M_RedPoint

--Boss模块
M_Boss = {
	module = "boss",
	getMyKillInfo		= {id = 0x1001, type = 1, request = nil, response = "boss.MyKillInfo", log = 2, desc = "获取个人击杀信息"},
	getKillInfo 		= {id = 0x1002, type = 1, request = nil, response = "boss.KillInfo", log = 2, desc = "获取击杀"},
	handleKillBoss			= {id = 0x10a1, type = 2, response = "boss.KillBoss", log = 0, desc = "捕获Boss"},
}
protoMap.Boss 			= M_Boss

-- 排行榜
M_Rank 	=	{
	module 				= "rank",
	getArenaDayInfo 	= {id = 0x1101, type = 1, response = "rank.ArenaDayInfo", log = 0, desc = "获取竞技场每日排名"},
	getArenaWeekInfo 	= {id = 0x1102, type = 1, response = "rank.ArenaWeekInfo", log = 0, desc = "获取竞技场每周排名"},
	getAwardInfo 		= {id = 0x1103, type = 1, response = "rank.AwardsInfo", log = 0, desc = "查看竞技场奖励信息"},
}
protoMap.Rank 			= M_Rank

--邮件模块
M_Mail = {
	module = "mail",
	getAllMailsStatus 	= {id = 0x1201, type = 1, response = "mail.GetAllMailsStateResponse", log = 2, desc = "获取所有邮件状态" },
	readMail			= {id = 0x1202, type = 1, request = "int64", response = "mail.ReadMailResponse", log = 2, desc = "阅读邮件"},
	getAttachment		= {id = 0x1203, type = 1, request = "int64", response = "mail.RecvAllAttachResponse", log = 2, desc = "获取附件" },
	recvAllAttach 		= {id = 0x1204, type = 1, request = "int32", response = "mail.RecvAllAttachResponse", log = 2, desc = "获取附件" },
	delMail 			= {id = 0x1205, type = 1, request = "int64", response = "int64", log = 2, desc = "删除邮件"},
	delAllMail 			= {id = 0x1206, type = 1, request = "int32", response = "mail.RecvAllAttachResponse", log = 2, desc = "删除全部邮件"},
	handleRecvMail 			= {id = 0x12a1, type = 2, response = "mail.RecvMail", log = 2, desc = "推送玩家新收到的邮件"},
}
protoMap.Mail 			= M_Mail

--在线奖励
M_OnlineAward = {
	module = "online_award",
	getInfo  			= {id = 0x1301, type = 1, request = nil, response = "oa.OnlineAwardInfo", log = 2, desc = "获取在线奖励信息"},
	receiveAward		= {id = 0x1302, type = 1, request = "int32", response = "oa.OnlineAwardInfo", log = 2, desc = "领取在线奖励"},

}
protoMap.OnlineAward 			= M_OnlineAward

--每日任务
M_Task = {
	module = "task",
	getTaskList  		= {id = 0x1401, type = 1, request = nil, response = "task.TaskList", log = 2, desc = "获取任务列表"},
	receiveAward		= {id = 0x1402, type = 1, request = "int32", response = nil, log = 2, desc = "领取奖励"},
	receiveTotalAward 	= {id = 0x1403, type = 1, log = 2, desc = "领取全完成奖励"},

	handleTaskUpdate		= {id = 0x14a1, type = 2, response = "task.TaskUpdateInfo", log = 2, desc = "任务状态改变"},

}
protoMap.Task 			= M_Task

--福袋
M_LuckyBag = {
	module = "lucky_bag",
	getInfo 			= {id = 0x1501, type = 1, response = "lucky_bag.info", log = 0, desc = "获取界面信息"},
	getGoodsRecords 	= {id = 0x1502, type = 1, response = "lucky_bag.goodsRecord", log = 0, desc = "获取玩家实物记录"},
	open 				= {id = 0x1503, type = 1, request = "int32", response = "lucky_bag.awardInfo", log = 2, desc = "开福袋"},
	handleSysBagOpen 		= {id = 0x15a1, type = 2, response = "lucky_bag.record", log = 0, desc = "推送玩家开出系统记录"},
	handleBagNumUpdate 		= {id = 0x15a2, type = 2, response = "int32", log = 0, desc = "福袋数量变化"},
}
protoMap.LuckyBag 		= M_LuckyBag


-- 福利奖池
M_Pot = {
	module = "pot",
	getInfo 		 	= {id = 0x1601, type = 1, response = "pot.Info", log = 0, desc = "获取奖池信息"},
	bet 				= {id = 0x1602, type = 1, request = "pot.Bet", log = 2, desc = "下注"},
	getHistoryDetail 	= {id = 0x1603, type = 1, request = "role.String", response = "pot.Record", log = 0, desc = "获取记录详情"},
	getRoundDetail 		= {id = 0x1604, type = 1, request = "role.String", response = "pot.Round", log = 0, desc = "获取开奖记录"},
	handleCodeOpen 			= {id = 0x16a1, type = 2, response = "pot.Open", log = 0, desc = "开奖了"}, 
	handleSendAward 		= {id = 0x16a2, type = 2, response = "pot.Award", log = 0, desc = "发奖了"},		
}
protoMap.Pot 			= M_Pot

-- 七天登录
M_SevenDay = {
	module 	= "seven_day",
	getInfo 			= {id = 0x1701, type = 1, response = "seven_day.Info", log = 0, desc = "获取七天登录信息"},
	getLoginAward 		= {id = 0x1702, type = 1, request = "int32", log = 2, desc = "获取登录奖励"},
	getChargeAward 		= {id = 0x1703, type = 1, request = "int32", log = 2, desc = "获取充值奖励"},
}
protoMap.SevenDay 		= M_SevenDay

-- 签到
M_Sign = {
	module = "sign",
	getInfo 			= {id = 0x1801, type = 1, response = "sign.Info", log = 0, desc = "获取签到信息"},
	getDayAward 		= {id = 0x1802, type = 1, request = "int32", log = 2, desc = "日签到"},
	getWeekAward 		= {id = 0x1803, type = 1, request = "int32", log = 2, desc = "周累积签到"},
	updateInfo 			= {id = 0x18a1, type = 2, response = "sign.Info", log = 0, desc = "更新签到信息"},
}
protoMap.Sign 			= M_Sign

--许愿池
M_WishPool = {
	module = "wish_pool",
	getInfo 			= {id = 0x1901, type = 1, response = "wish_pool.info", log = 0, desc = "获取界面信息"},
	getGoodsRecords 	= {id = 0x1902, type = 1, response = "wish_pool.goodsRecord", log = 0, desc = "获取玩家实物记录"},
	makeWish 			= {id = 0x1903, type = 1, request  = "int32", response = "wish_pool.awardInfo", log = 2, desc = "许愿"},
}
protoMap.WishPool      = M_WishPool

--签到奖励
M_SignDisk = {
	module = "sign_disk",
	getInfo 			= {id = 0x1a01, type = 1, response = "sign_disk.info", log = 0, desc = "获取界面信息"},
	signDraw 			= {id = 0x1a02, type = 1, response = "int32", log = 2, desc = "签到抽奖"},
	getTotalSignAward   = {id = 0x1a03, type = 1, request = "int32", log = 2, desc = "领取累计奖励"},
}
protoMap.SignDisk       = M_SignDisk 

--聚宝盆
M_TreasureBowl = {
	module = "treasure_bowl",
	getInfo 			= {id = 0x1b01, type = 1, response = "treasure_bowl.Info", log = 0, desc = "获取界面信息"},
	join 				= {id = 0x1b02, type = 1, response = "int32", log = 2, desc = "抽奖"},
}
protoMap.TreasureBowl   = M_TreasureBowl

--刮刮乐
M_Coupon = {
	module = "coupon",
	getInfo 			= {id = 0x1c01, type = 1, response = "coupon.Info", log = 0, desc = "获取界面信息"},
	getAward			= {id = 0x1c02, type = 1, request = "int32", log = 2, desc = "领取奖励"},
	openCard			= {id = 0x1c03, type = 1, request = "int32", response = "int32", log = 2, desc = "刮开卡"},
}
protoMap.Coupon   = M_Coupon

--福袋
M_Lottery = {
	module = "lottery",
	getInfo 			= {id = 0x1d01, type = 1, response = "lottery.Info", log = 0, desc = "获取界面信息"},
	getGoodsRecords 	= {id = 0x1d02, type = 1, response = "lottery.GoodsRecord", log = 0, desc = "获取玩家实物记录"},
	lottery 			= {id = 0x1d03, type = 1, request = "int32", response = "lottery.AwardInfo", log = 2, desc = "寻宝"},
	getRank 			= {id = 0x1d04, type = 1, request = nil, response = "lottery.RankInfo", log = 2, desc = "获取排行"},
	handleSysLottery 		= {id = 0x1da1, type = 2, response = "lottery.Record", log = 0, desc = "推送玩家开出系统记录"},
}
protoMap.M_Lottery 		= M_Lottery

--祈福
M_Bless = {
	module = "bless",
	getInfo 			= {id = 0x1e01, type = 1, response = "bless.Info", log = 0, desc = "获取界面信息"},
	bless 				= {id = 0x1e02, type = 1, request = "int32", response = "int32", log = 0, desc = "祈福"},
	getAward 			= {id = 0x1e03, type = 1, request = "int32", log = 0, desc = "领取奖品"},
	getGoodsRecords 	= {id = 0x1e04, type = 1, response = "bless.GoodsRecord", log = 0, desc = "获取玩家实物记录"},
}
protoMap.M_Bless 		= M_Bless

--疯狂的宝箱
M_CrazyBox = {
	module = "crazy_box",
	getInfo 			= {id = 0x1f01, type = 1, response = "crazy_box.Info", log = 0, desc = "获取界面信息"},
	openBox 			= {id = 0x1f02, type = 1, request = "int32", response = "int32", log = 0, desc = "开箱"},
	getGoodsRecords 	= {id = 0x1f03, type = 1, response = "crazy_box.GoodsRecord", log = 0, desc = "获取玩家实物记录"},
}
protoMap.M_CrazyBox 		= M_CrazyBox

--每日充值
M_DailyCharge = {
	module = "daily_charge",
	getInfo 			= {id = 0x1f11, type = 1, response = "daily_charge.Info", log = 0, desc = "获取界面信息"},
	getDailyAward 		= {id = 0x1f12, type = 1 , log = 0, desc = "获取每日充值奖励"},
	getContinueAward 	= {id = 0x1f13, type = 1, request = "int32", log = 0, desc = "获取持续充值奖励"},
}
protoMap.M_DailyCharge 		= M_DailyCharge

--邀请好友
M_Invite = {
	module = "invite",
	getInfo 			= {id = 0x2001, type = 1, response = "invite.Info", log = 0, desc = "获取界面信息"},
	getPlayAward 		= {id = 0x2002, type = 1, request = "int32", log = 0, desc = "获取畅玩奖励"},
	getInviteAward 		= {id = 0x2003, type = 1, request = "int32", log = 0, desc = "获取邀请奖励"},
	getChargeAward 		= {id = 0x2004, type = 1, log = 0, desc = "获取充值奖励"},
}
protoMap.M_Invite 		= M_Invite

--积分抽奖
M_ScoreLottery = {
	module = "score_lottery",
	getInfo 			= {id = 0x2101, type = 1, response = "score_lottery.Info", log = 0, desc = "获取界面信息"},
	lottery 			= {id = 0x2102, type = 1, request = "int32", response = "score_lottery.Lottery", log = 0, desc = "积分抽奖"},
	getAward 			= {id = 0x2103, type = 1, request = "int32", log = 0, desc = "领取累计奖励"},
}
protoMap.M_ScoreLottery 		= M_ScoreLottery

--摇钱树
M_MoneyTree = {
	module = "money_tree",
	getInfo 			= {id = 0x2201, type = 1, response = "money_tree.Info", log = 0, desc = "获取界面信息"},
	lottery 			= {id = 0x2202, type = 1, request = "int32", response = "money_tree.Lottery", log = 0, desc = "小(大)力一摇"},
	getGoodsRecords 	= {id = 0x2203, type = 1, response = "money_tree.goodsRecord", log = 0, desc = "获取实物信息"},
}
protoMap.M_MoneyTree 		= M_MoneyTree

--摇钱树
M_TreasurePalace = {
	module = "treasure_palace",
	getInfo 			= {id = 0x2301, type = 1, response = "treasure_palace.Info", log = 0, desc = "获取界面信息"},
	dice 				= {id = 0x2302, type = 1, response = "int32", log = 0, desc = "摇骰子"},
	openBox 			= {id = 0x2303, type = 1, response = "int32", log = 0, desc = "开宝箱"},
	getGoodsRecords 	= {id = 0x2304, type = 1, response = "treasure_palace.goodsRecord", log = 0, desc = "获取实物信息"},
}
protoMap.M_TreasurePalace 		= M_TreasurePalace

--海底遗迹
M_Relic = {
	module = "relic",
	getInfo 			= {id = 0x2401, type = 1, response = "int32", log = 0, desc = "获取界面信息"},
	lottery 			= {id = 0x2402, type = 1, response = "relic.relicInfo", log = 0, desc = "抽奖"},
	getGoodsRecords 	= {id = 0x2403, type = 1, response = "relic.goodsRecord", log = 0, desc = "获取实物信息"},
}
protoMap.M_Relic 		= M_Relic

--砸金蛋
M_Egg = {
	module = "egg",
	getInfo 			= {id = 0x2501, type = 1, response = "egg.Info", log = 0, desc = "获取界面信息"},
	openEgg 			= {id = 0x2502, type = 1, request = "int32", response = "int32", log = 0, desc = "开箱"},
}
protoMap.M_Egg 		= M_Egg

--彩金炮
M_GoldGun = {
	module = "gold_gun",
	getInfo 			= {id = 0x2601, type = 1, response = "int32", log = 0, desc = "获取界面信息"},
	lottery 			= {id = 0x2602, type = 1, request = "int32", response = "int32", log = 0, desc = "抽奖"},
	getGoodsRecords 	= {id = 0x2603, type = 1, response = "gold_gun.goodsRecord", log = 0, desc = "获取实物信息"},
}
protoMap.M_GoldGun 		= M_GoldGun

--明日礼包
M_MorrowGift = {
	module = "morrow_gift",
	getInfo 			= {id = 0x2701, type = 1, response = "morrow_gift.MorrowGiftInfo", log = 0, desc = "获取明日礼包信息"},
	getAward 			= {id = 0x2702, type = 1, response = "morrow_gift.MorrowGiftInfo", log = 0, desc = "领取奖励"},
}
protoMap.M_MorrowGift 		= M_MorrowGift

return protoMap