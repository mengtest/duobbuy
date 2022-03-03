local activityConst = {
	dailyActivityId = 1,
	roundActivityId = 2,

	curRound = 1,

	buttonStatus = {
		charge = 1,    --待充值
		award  = 2,    --待领取
		over   = 3,    --已结束
	},

	activityTime = {
		chargeDisk 			= 1,	--充值转盘		***
		glodBag 			= 2,	--金币福袋		
		fruit 				= 3,	--水果机			***
		redPocket 			= 4,	--红包来袭		***
		bindPhone 			= 5,	--绑定手机		***
		dayShare 			= 6,	--天天分享		
		bossCome 			= 7,	--boss奖品来袭
		arenaRank 			= 8,	--竞技场排行
		dayTask 			= 9,	--每日任务		***
		daySign 			= 10,	--连续七天领取奖励（发放Q币用）		***
		luckyBag 			= 11,  	--幸运福袋		***
		signDisk 			= 12,  	--每日签到(转盘)		***
		wishPool 			= 13,  	--许愿池
		treasureBowl 		= 14,  	--聚宝盆			
		lottery 			= 15,  	--寻宝
		coupon	 			= 16,  	--刮刮乐
		crazyBox 			= 18, 	--疯狂的宝箱
		bless 				= 19,   --祈福
		invite 				= 21,  	--好友邀请
		dailyCharge 		= 22,  	--每日充值		***
		scoreLottery 		= 23, 	--积分抽奖
		moneyTree 			= 24, 	--摇钱树
		treasurePalace 		= 25, 	--龙宫宝藏
		relic 				= 26, 	--遗迹
		egg 				= 27, 	--砸金蛋
		gift 				= 28, 	--大礼包（周期内每天邮件发送奖励）
	},

	activityStatus = {
		open = 1,	--开启
		close = 2,	--关闭
	},
}

return activityConst