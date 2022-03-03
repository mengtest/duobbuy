--[[
	类型, 名称, 货物, 描述1, 描述2, 价格, 展示图标, 排序
	id, name, goods, desc1, desc2, price, icon, rank
]]
local shop_bag = {
	[301] = {
			id = 301,
			name = [[10元金币福袋]],
			goods = {goodsId=1,amount=50000},
			desc1 = [[<font size=20>最高送</font><font size=22 color=#fffc00>5000</font><font size=20>金币</font>]],
			desc2 = [[5W金币（每日限购1次）]],
			price = 10,
		},
	[302] = {
			id = 302,
			name = [[50元金币福袋]],
			goods = {goodsId=1,amount=250000},
			desc1 = [[<font size=20>最高送</font><font size=22 color=#fffc00>2.5W</font><font size=20>金币</font>]],
			desc2 = [[25W金币（每日限购1次）]],
			price = 50,
		},
	[303] = {
			id = 303,
			name = [[100元金币福袋]],
			goods = {goodsId=1,amount=500000},
			desc1 = [[<font size=20>最高送</font><font size=22 color=#fffc00>5W</font><font size=20>金币</font>]],
			desc2 = [[50W金币（每日限购1次）]],
			price = 100,
		},
	[304] = {
			id = 304,
			name = [[500元金币福袋]],
			goods = {goodsId=1,amount=2500000},
			desc1 = [[<font size=20>最高送</font><font size=22 color=#fffc00>25W</font><font size=20>金币</font>]],
			desc2 = [[250W金币（每日限购1次）]],
			price = 500,
		},
	[305] = {
			id = 305,
			name = [[1000元金币福袋]],
			goods = {goodsId=1,amount=5000000},
			desc1 = [[<font size=20>最高送</font><font size=22 color=#fffc00>50W</font><font size=20>金币</font>]],
			desc2 = [[500W金币（每日限购1次）]],
			price = 1000,
		},
}
return shop_bag