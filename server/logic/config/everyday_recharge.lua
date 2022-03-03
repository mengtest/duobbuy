--[[
	序号, 内容, 奖励
	day, content, award
]]
local everyday_recharge = {
	[1] = {
			day = 1,
			content = {{"gold_1","3000金币"},{"gun_14","节能炮(2小时)"}},
			award = {{goodsId=1,amount=3000},{gunId=12,time=7200}},
		},
	[2] = {
			day = 2,
			content = {{"gold_1","3000金币"},{"gun_07","金刚怒吼(2小时)"}},
			award = {{goodsId=1,amount=3000},{gunId=5,time=7200}},
		},
	[3] = {
			day = 3,
			content = {{"gold_1","3000金币"},{"gun_11","冰封领域(2小时)"}},
			award = {{goodsId=1,amount=3000},{gunId=9,time=7200}},
		},
	[4] = {
			day = 4,
			content = {{"gold_1","3000金币"},{"gun_05","极光魅影(2小时)"}},
			award = {{goodsId=1,amount=3000},{gunId=3,time=7200}},
		},
	[5] = {
			day = 5,
			content = {{"gold_1","3000金币"},{"gun_10","双生之力(2小时)"}},
			award = {{goodsId=1,amount=3000},{gunId=8,time=7200}},
		},
	[6] = {
			day = 6,
			content = {{"gold_1","3000金币"},{"gun_13","狂暴修罗(2小时)"}},
			award = {{goodsId=1,amount=3000},{gunId=11,time=7200}},
		},
	[7] = {
			day = 7,
			content = {{"gold_1","3000金币"},{"gun_12","大力神(2小时)"}},
			award = {{goodsId=1,amount=3000},{gunId=10,time=7200}},
		},
}
return everyday_recharge