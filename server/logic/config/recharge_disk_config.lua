--[[
	类型, 组, 权重, 图标, 内容, 奖励, 跑马灯
	id, group, weight, icon, content, award, notice
]]
local recharge_disk_config = {
	[1] = {
			id = 1,
			group = 5,
			weight = 5,
			icon = [[gun_12]],
			content = [[大力神]],
			award = {gunId=10},
			notice = 1,
		},
	[2] = {
			id = 2,
			group = 2,
			weight = 80,
			icon = [[gold_1]],
			content = [[18000金币]],
			award = {goodsId=1,amount=18000},
			notice = 0,
		},
	[3] = {
			id = 3,
			group = 1,
			weight = 130,
			icon = [[gold_1]],
			content = [[11000金币]],
			award = {goodsId=1,amount=11000},
			notice = 0,
		},
	[4] = {
			id = 4,
			group = 4,
			weight = 10,
			icon = [[gold_2]],
			content = [[320000金币]],
			award = {goodsId=1,amount=320000},
			notice = 1,
		},
	[5] = {
			id = 5,
			group = 1,
			weight = 370,
			icon = [[gold_1]],
			content = [[4000金币]],
			award = {goodsId=1,amount=4000},
			notice = 0,
		},
	[6] = {
			id = 6,
			group = 3,
			weight = 15,
			icon = [[gold_2]],
			content = [[120000金币]],
			award = {goodsId=1,amount=120000},
			notice = 1,
		},
	[7] = {
			id = 7,
			group = 3,
			weight = 20,
			icon = [[gold_2]],
			content = [[80000金币]],
			award = {goodsId=1,amount=80000},
			notice = 1,
		},
	[8] = {
			id = 8,
			group = 2,
			weight = 60,
			icon = [[gold_1]],
			content = [[28000金币]],
			award = {goodsId=1,amount=28000},
			notice = 0,
		},
	[9] = {
			id = 9,
			group = 3,
			weight = 30,
			icon = [[gold_2]],
			content = [[47000金币]],
			award = {goodsId=1,amount=47000},
			notice = 1,
		},
	[10] = {
			id = 10,
			group = 2,
			weight = 40,
			icon = [[gold_1]],
			content = [[36000金币]],
			award = {goodsId=1,amount=36000},
			notice = 0,
		},
	[11] = {
			id = 11,
			group = 1,
			weight = 230,
			icon = [[gold_1]],
			content = [[7000金币]],
			award = {goodsId=1,amount=7000},
			notice = 0,
		},
	[12] = {
			id = 12,
			group = 4,
			weight = 10,
			icon = [[gold_2]],
			content = [[500000金币]],
			award = {goodsId=1,amount=500000},
			notice = 1,
		},
}
return recharge_disk_config