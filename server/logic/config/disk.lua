--[[
	类型, 权重, 奖励, 暴击值, 
	id, weight, award, crit, 
]]
local disk = {
	[1] = {
			id = 1,
			weight = 600,
			award = {goodsId=1,amount=1000},
			crit = 999,
		},
	[2] = {
			id = 2,
			weight = 300,
			award = {goodsId=1,amount=2000},
			crit = 999,
		},
	[3] = {
			id = 3,
			weight = 100,
			award = {goodsId=1,amount=3000},
			crit = 1000,
		},
	[4] = {
			id = 4,
			weight = 0,
			award = {goodsId=1,amount=5000},
			crit = 1000,
		},
	[5] = {
			id = 5,
			weight = 0,
			award = {goodsId=1,amount=10000},
			crit = 1000,
		},
	[6] = {
			id = 6,
			weight = 0,
			award = {goodsId=2,amount=1},
			crit = 1000,
		},
	[7] = {
			id = 7,
			weight = 0,
			award = {goodsId=2,amount=2},
			crit = 1000,
		},
	[8] = {
			id = 8,
			weight = 0,
			award = {goodsId=2,amount=5},
			crit = 1000,
		},
}
return disk