local treasurePalaceConst = {
	diceCost = 10, --摇骰子消耗

	sendStatus = {			--实物奖品的处理状态
		inHandle = 1,
		done 	 = 2,
	},

	goodsType = {		    --奖品类型
		game = 1,			--金币或夺宝卡
		gun = 2,			--炮塔
		real = 3,			--实物(京东卡等)
	},

	Source = {
		map = 1,  --地图获得
		box = 2,  --宝箱获得
	},
}

return treasurePalaceConst