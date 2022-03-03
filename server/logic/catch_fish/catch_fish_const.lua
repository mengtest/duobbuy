local CatchFishConst = {}

CatchFishConst.JI_GUANG_GUN = 3     		--极光魅影炮类型ID
CatchFishConst.SHUANG_SHENG_ZHI_LI = 8      --双生之力炮类型ID
CatchFishConst.BING_DONG = 9      			--冰冻炮类型ID
CatchFishConst.CRIT = 11     				--狂暴炮类型ID
CatchFishConst.JIE_NENG = 12     			--节能炮类型ID
CatchFishConst.CHENG_JIE = 13     			--爆裂惩戒炮类型ID
CatchFishConst.GOLD_GUN = 14     			--黄金炮类型ID
CatchFishConst.SLICE_GUN = 15     			--切鱼炮类型ID

CatchFishConst.ROOM_PLAYER_COUNT = 4

-- 切鱼相关
CatchFishConst.SLICE_TIME = 5				-- 切鱼时间
CatchFishConst.SLICE_RATE = 6				-- 切鱼频率（每秒最多5次+1次误差）

CatchFishConst.RoomType = {
	NORMAL = 1,
	VIP = 2,
	ARENA = 3,
}

CatchFishConst.FishGroupType = {
	BIG_FISH 		= 12,	-- 大鱼
	BIGGEST_FISH 	= 13,	-- 超大鱼
}

CatchFishConst.FishType = {
	SAME_FISH = 101,
	THREE_FISH = 102,
	FOUR_FISH = 103,
	LOCAL_BOMB = 104,	-- 局部炸弹
	GLOBAL_BOMB = 105,	-- 全屏炸弹
	COMPOSE_FISH = 106,
	GOLD_FISH = 301,	-- 囤金鱼
}

CatchFishConst.ArenaType = {
	GOLD = 1,
	TREASURE = 2,
}

CatchFishConst.ArenaLevel = {
	LEVEL_1 = 1,
	LEVEL_2 = 2,
	LEVEL_3 = 3,
}

CatchFishConst.PlayerState = {
	NORMAL = 1,
	OFFLINE = 2,
	GIVE_UP = 3,
}

return CatchFishConst