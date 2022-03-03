local sevenDayConst = {
	maxDay = 7,
	awardStatus = {
		canGet = 1,		--可领取
		hadGet = 2,		--已领取
	},
	chargeStatus = {
		canNotGet = 1,	--未达到
		canGet = 2,		--可以领取
		hadGet = 3,		--已领取
		timeOut = 4,	--过期
	}, 
}

return sevenDayConst