--[[
	ID, 累计次数, 打开箱子, 关闭箱子, 名称, 奖励图标, 奖励
	id, times, boxOpen, boxClose, name, awardIcon, award
]]
local score_lottery_total = {
	[1] = {
			id = 1,
			times = 10,
			boxOpen = [[box1_1]],
			boxClose = [[box1_2]],
			name = [[50000金币]],
			awardIcon = [[gold_2]],
			award = {goodsId=1,amount=50000},
		},
	[2] = {
			id = 2,
			times = 20,
			boxOpen = [[box2_1]],
			boxClose = [[box2_2]],
			name = [[100000金币]],
			awardIcon = [[gold_2]],
			award = {goodsId=1,amount=100000},
		},
	[3] = {
			id = 3,
			times = 50,
			boxOpen = [[box3_1]],
			boxClose = [[box3_2]],
			name = [[200000金币]],
			awardIcon = [[gold_2]],
			award = {goodsId=1,amount=200000},
		},
	[4] = {
			id = 4,
			times = 80,
			boxOpen = [[box4_1]],
			boxClose = [[box4_2]],
			name = [[300000金币]],
			awardIcon = [[gold_2]],
			award = {goodsId=1,amount=300000},
		},
	[5] = {
			id = 5,
			times = 120,
			boxOpen = [[box5_1]],
			boxClose = [[box5_2]],
			name = [[炮塔]],
			awardIcon = [[gun_10]],
			award = {gunId=8},
		},
}
return score_lottery_total