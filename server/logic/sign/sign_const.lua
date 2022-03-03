local signConst = {
	dayStatus = {
		toSign = 1, --待签到
		hadSign = 2,	--已签到
		notSign = 3,	--待补签
		canNotSign = 4,	--不能签到
	},
	weekStatus = {
		canNot = 1,	--未达到
		canGet = 2,	--可领取
		hadGet = 3,	--已领取
	},
	delaySignCost = {{goodsId = 2, amount = 1}}
}

return signConst