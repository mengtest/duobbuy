local blessConst = {
	blessTreasureCost = 10,   --祈福消耗的夺宝卡数

	goodsType = {		    --奖品类型
		game = 1,			--金币或夺宝卡
		gun = 2,			--炮塔
		real = 3,			--实物(京东卡等)
	},

	sendStatus = {			--实物奖品的处理状态
		inHandle = 1,
		done 	 = 2,
	},
	blessMustGet = {goodsId=1,amount=20000}, --祈福必得奖励

}

return blessConst