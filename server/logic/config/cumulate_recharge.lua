--[[
	类型, 名称, icon, 奖励
	id, recharge, icon, award
]]
local cumulate_recharge = {
	[1] = {
			id = 1,
			recharge = 100,
			icon = [[gold_1]],
			award = {goodsId=1,amount=5000},
		},
	[2] = {
			id = 2,
			recharge = 300,
			icon = [[gold_2]],
			award = {goodsId=1,amount=25000},
		},
	[3] = {
			id = 3,
			recharge = 700,
			icon = [[gold_3]],
			award = {goodsId=1,amount=50000},
		},
	[4] = {
			id = 4,
			recharge = 1000,
			icon = [[gold_4]],
			award = {goodsId=1,amount=100000},
		},
	[5] = {
			id = 5,
			recharge = 2000,
			icon = [[gold_5]],
			award = {goodsId=1,amount=200000},
		},
	[6] = {
			id = 6,
			recharge = 5000,
			icon = [[gold_6]],
			award = {goodsId=1,amount=750000},
		},
}
return cumulate_recharge