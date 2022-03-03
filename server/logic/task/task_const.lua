local taskConst = {
	TaskType = {
		GoldCost = 1,		--金币消耗
		TreasureGet = 2,	--夺宝卡获得
		FishShot = 3,		--打死鱼
		ArenaJoin = 4,		--竞技场参加
		FundJoin = 5,		--夺宝参加
		FishWave = 6,		--鱼群到来
	},
	TaskStatus = {
		canNot = 1,		--未完成
		canGet = 2,		--已完成
		hadGet = 3,		--已领取
	},
	TotalStatus = {
		canNot = 1,		--未完成
		canGet = 2,		--已完成
		hadGet = 3,		--已领取
	},
	TaskStepKey = "TaskStep",
	TaskStatusKey = "TaskStatus",
	TaskDayKey = "TaskDay",
	ActivityId = 9,
}

return taskConst