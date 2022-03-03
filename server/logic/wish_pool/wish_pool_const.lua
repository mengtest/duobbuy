local wishPoolConst = {

	initAwardNum = 100000,  --许愿池初始化的奖励数量

	sendStatus = {			--实物奖品的处理状态
		inHandle = 1,
		done 	 = 2,
	},

	goodsType = {		    --奖品类型
		game = 1,			--金币或夺宝卡
		gun = 2,			--炮塔
		real = 3,			--实物(京东卡等)
	},

	singleWishTreasureCost = 10,  --单次许愿花费的夺宝卡数量

	wishNumType = {
		once	=	1,		--许愿1次
		ten		=	10,		--许愿10次
	}
}

return wishPoolConst