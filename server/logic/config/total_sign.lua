--[[
	累积天数, 打开箱子, 关闭箱子, 名称, 奖励图标, 奖励
	day, boxOpen, boxClose, name, awardIcon, award
]]
local total_sign = {
 {
		day = 3,
		boxOpen = [[box_0_1]],
		boxClose = [[box_0_2]],
		name = [[3000金币]],
		awardIcon = [[gold_1]],
		award = {goodsId=1,amount=3000},
	},
 {
		day = 7,
		boxOpen = [[box_1_1]],
		boxClose = [[box_1_2]],
		name = [[5000金币]],
		awardIcon = [[gold_2]],
		award = {goodsId=1,amount=5000},
	},
 {
		day = 12,
		boxOpen = [[box_2_1]],
		boxClose = [[box_2_2]],
		name = [[极光魅影(1天)]],
		awardIcon = [[gun_05]],
		award = {gunId=3,time=86400},
	},
 {
		day = 21,
		boxOpen = [[box_3_1]],
		boxClose = [[box_3_2]],
		name = [[20000金币]],
		awardIcon = [[gold_4]],
		award = {goodsId=1,amount=20000},
	},
}
return total_sign