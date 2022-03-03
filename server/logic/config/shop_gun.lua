--[[
	类型, 名称, 货物, 新品, 描述1, 描述2, 价格, 展示图标, 排序, 获取途径
	id, name, goods, isNew, desc1, desc2, price, icon, rank, get
]]
local shop_gun = {
	[1] = {
			id = 1,
			name = [[基础炮]],
			goods = {gunId=1},
			isNew = 0,
			desc1 = [[]],
			desc2 = [[<font outline=#000000,1 >普通炮塔</font>]],
			price = 0,
			get = {},
		},
	[3] = {
			id = 3,
			name = [[极光魅影]],
			goods = {gunId=3},
			isNew = 0,
			desc1 = [[]],
			desc2 = [[<font outline=#000000,1 >几率触发闪电，会同时命中渔场内其他鱼</font>]],
			price = 188,
			get = {},
		},
	[5] = {
			id = 5,
			name = [[金刚怒吼]],
			goods = {gunId=5},
			isNew = 0,
			desc1 = [[]],
			desc2 = [[<font outline=#000000,1 >发炮速度提升30%，全火力覆盖无漏网之鱼</font>]],
			price = 158,
			get = {},
		},
	[7] = {
			id = 7,
			name = [[幽冥骨魂]],
			goods = {gunId=7},
			isNew = 0,
			desc1 = [[]],
			desc2 = [[<font outline=#000000,1 >激活"能量槽",捕鱼过程吸取能量,能量槽涨满获得夺宝卡</font>]],
			price = 488,
			get = {name = "LOTTERY_VIEW",checkType = "Hunt"},
		},
	[8] = {
			id = 8,
			name = [[双生之力]],
			goods = {gunId=8},
			isNew = 1,
			desc1 = [[]],
			desc2 = [[<font outline=#000000,1 >几率出现多倍暴击，获得多倍奖励</font>]],
			price = 648,
			get = {name = "LUCKY_BAG",checkType = "Bag"},
		},
	[9] = {
			id = 9,
			name = [[冰封领域]],
			goods = {gunId=9},
			isNew = 1,
			desc1 = [[]],
			desc2 = [[<font outline=#000000,1 >寒气积累满后可释放技能，冰冻全屏5秒钟</font>]],
			price = 298,
			get = {},
		},
	[10] = {
			id = 10,
			name = [[大力神]],
			goods = {gunId=10},
			isNew = 1,
			desc1 = [[]],
			desc2 = [[<font outline=#000000,1 >升级最高炮倍为1万倍，助您收益翻翻</font>]],
			price = 998,
			get = {name = "WISHWELL",checkType = "Recharge"},
		},
	[11] = {
			id = 11,
			name = [[狂暴修罗]],
			goods = {gunId=11},
			isNew = 1,
			desc1 = [[]],
			desc2 = [[<font outline=#000000,1 >怒气积累满后可释放技能，5秒钟内大幅度提升捕获概率</font>]],
			price = 999,
			get = {name = "BOWL_VIEW",checkType = "Recharge"},
		},
}
return shop_gun