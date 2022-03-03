local eggConst = {
	openStatus = {
		isOpen = 1,  --已开
		notOpen = 2, --未开
	},

	initCycle = 1,  --初始化轮次

	maxCycle = 7,  	--最大轮次

	goodsType = {		    --奖品类型
		game = 1,			--金币或夺宝卡
		gun = 2,			--炮塔
		real = 3,			--实物(京东卡等)
	},

	sendStatus = {			--实物奖品的处理状态
		inHandle = 1,
		done 	 = 2,
	},
}

return eggConst