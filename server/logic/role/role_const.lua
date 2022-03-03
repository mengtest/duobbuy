local roleConst = {}
local logConst = require("game.log_const")

roleConst = {
	recordGoldSec = 60, 	--金币入库最小间隔(s)
	logGoldNum 	= 1000,		--金币日志入库最大变化数量
	logFishGoldNum = 1000, 	--渔场金币日志入库最大变化数量
	freeGoldSec = 7200,        --免费金币时间间隔
	freeGoldMax = 2000,  --免费金币上限
	freeGoldTime = 2,		--每日免费金币次数

	GOLD_ID = 1,			--金币资源id
	TREASURE_ID = 2,		--夺宝卡资源id
	LUCKY_BAG_ID = 3, 		--福袋资源id

	SHOP_MATERIAL = 1, 	-- 资源商城
	SHOP_GUN = 2,		-- 炮塔商城
	SHOP_GIFT = 3,		-- 超值商城
	SHOP_BAG = 4,		-- 福袋商城

	novices = {
		reg = 1,			--注册
		dailyFree = 2,		--免费金币
	},

	goldGunId = 7, 		--黄金炮id
	goldEnergyStep = 400000, 	-- 黄金炮兑换夺宝卡能量值
	frozenEnergyMax = 250000,	-- 冰冻炮能量上限
	critEnergyMax = 250000,		--狂暴炮能量上限
	sliceEnergyMax = 20000,		--切鱼炮能量上限

	bagChangeVersion = 6, --换包版本
	bagChangeGold = 5000,

	returnLogoutDate = { year = 2016, month = 6, day = 15, hour = 0, min = 0, sec = 0 },
	vipAwardGold = 88888,
	weChatFollowStatus = {
		show = 1,
		hide = 2,
	},

	-- 金币->有效金币转换系数
	NotFishGoldRatio = {
		[logConst.newPlayerFundGet] = {freeRoleRatio = 0.1, vipRoleRatio = 0.2}
	}
}

return roleConst