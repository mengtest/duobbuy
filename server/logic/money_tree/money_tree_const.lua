local moneyTreeConst = {
	initAwardNum = 50000,  --初始化的奖励数量
	singleCost = 5, --单次消耗的夺宝卡数

	sendStatus = {			--实物奖品的处理状态
		inHandle = 1,
		done 	 = 2,
	},

	goodsType = {		    --奖品类型
		game = 1,			--金币或夺宝卡
		gun = 2,			--炮塔
		real = 3,			--实物(京东卡等)
	},
}

return moneyTreeConst