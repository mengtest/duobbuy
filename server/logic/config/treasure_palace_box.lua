--[[
	类型, 权重, 图标, 内容, 奖励类型, 奖励, 跑马灯
	id, weight, icon, content, type, award, notice
]]
local treasure_palace_box = {
	[1] = {
			id = 1,
			weight = 10,
			icon = [[gun_12]],
			content = [[炮塔]],
			type = 2,
			award = {gunId=10},
			notice = 1,
		},
	[2] = {
			id = 2,
			weight = 50,
			icon = [[prize_big_04]],
			content = [[100京东卡]],
			type = 3,
			award = {prizeId=14},
			notice = 1,
		},
	[3] = {
			id = 3,
			weight = 80,
			icon = [[prize_big_03]],
			content = [[50京东卡]],
			type = 3,
			award = {prizeId=13},
			notice = 1,
		},
	[4] = {
			id = 4,
			weight = 50,
			icon = [[gold_big]],
			content = [[50万金币]],
			type = 1,
			award = {goodsId=1,amount=500000},
			notice = 1,
		},
	[5] = {
			id = 5,
			weight = 100,
			icon = [[gold_big]],
			content = [[20万金币]],
			type = 1,
			award = {goodsId=1,amount=200000},
			notice = 1,
		},
	[6] = {
			id = 6,
			weight = 200,
			icon = [[gold_big]],
			content = [[10万金币]],
			type = 1,
			award = {goodsId=1,amount=100000},
			notice = 1,
		},
}
return treasure_palace_box