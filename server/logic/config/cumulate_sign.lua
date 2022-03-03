--[[
	累积天数, 打开箱子, 关闭箱子, 名称, 奖励图标, 奖励
	day, boxOpen, boxClose, name, awardIcon, award
]]
local cumulate_sign = {
 {
		day = 3,
		boxOpen = [[box_1_1]],
		boxClose = [[box_1_2]],
		name = [[1000金币]],
		awardIcon = [[gold_2]],
		award = {goodsId=1,amount=1000},
	},
 {
		day = 5,
		boxOpen = [[box_2_1]],
		boxClose = [[box_2_2]],
		name = [[2000金币]],
		awardIcon = [[gold_2]],
		award = {goodsId=1,amount=2000},
	},
 {
		day = 7,
		boxOpen = [[box_3_1]],
		boxClose = [[box_3_2]],
		name = [[极光魅影(3小时)]],
		awardIcon = [[gun_05]],
		award = {gunId=3,time=10800},
	},
}
return cumulate_sign