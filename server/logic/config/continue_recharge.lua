--[[
	ID, 累积天数, 打开箱子, 关闭箱子, 名称, 奖励图标, 奖励
	id, day, boxOpen, boxClose, name, awardIcon, award
]]
local continue_recharge = {
	[1] = {
			id = 1,
			day = 3,
			boxOpen = [[box_0_1]],
			boxClose = [[box_0_2]],
			name = [[8000金币]],
			awardIcon = [[gold_2]],
			award = {goodsId=1,amount=8000},
		},
	[2] = {
			id = 2,
			day = 7,
			boxOpen = [[box_1_1]],
			boxClose = [[box_1_2]],
			name = [[25000金币]],
			awardIcon = [[gold_2]],
			award = {goodsId=1,amount=25000},
		},
	[3] = {
			id = 3,
			day = 15,
			boxOpen = [[box_2_1]],
			boxClose = [[box_2_2]],
			name = [[60000金币]],
			awardIcon = [[gold_2]],
			award = {goodsId=1,amount=60000},
		},
	[4] = {
			id = 4,
			day = 21,
			boxOpen = [[box_3_1]],
			boxClose = [[box_3_2]],
			name = [[节能炮(5天)]],
			awardIcon = [[gun_14]],
			award = {gunId=12,time=432000},
		},
}
return continue_recharge