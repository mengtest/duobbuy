--[[
	类型, 名称, 货物, 描述1, 描述2, 描述3, 描述4, 价格, 原价, 排序, 礼包ID
	id, name, goods, desc1, desc2, desc3, desc4, price, original_price, rank, gift_id
]]
local shop_vip = {
	[401] = {
			id = 401,
			name = [[富豪礼包*7天]],
			goods = {{goodsId=1,amount=50000}},
			desc1 = [[累积获得12万金币]],
			desc2 = [[5万金币]],
			desc3 = [[1万金币/天]],
			desc4 = [[重复购买可叠加天数]],
			price = 18,
			original_price = 24,
			gift_id = 1,
		},
	[402] = {
			id = 402,
			name = [[铂金礼包*7天]],
			goods = {{goodsId=1,amount=100000}},
			desc1 = [[累积获得24万金币]],
			desc2 = [[10万金币]],
			desc3 = [[2万金币/天]],
			desc4 = [[重复购买可叠加天数]],
			price = 38,
			original_price = 48,
			gift_id = 2,
		},
	[403] = {
			id = 403,
			name = [[钻石礼包*7天]],
			goods = {{goodsId=1,amount=220000}},
			desc1 = [[累积获得57万金币]],
			desc2 = [[22万金币]],
			desc3 = [[5万金币/天]],
			desc4 = [[重复购买可叠加天数]],
			price = 88,
			original_price = 114,
			gift_id = 3,
		},
	[404] = {
			id = 404,
			name = [[王者礼包*7天]],
			goods = {{goodsId=1,amount=350000}},
			desc1 = [[累积获得84万金币]],
			desc2 = [[35万金币]],
			desc3 = [[7万金币/天]],
			desc4 = [[重复购买可叠加天数]],
			price = 128,
			original_price = 168,
			gift_id = 4,
		},
	[405] = {
			id = 405,
			name = [[至尊礼包*7天]],
			goods = {{goodsId=1,amount=580000}},
			desc1 = [[累积获得142万金币]],
			desc2 = [[58万金币]],
			desc3 = [[12万金币/天]],
			desc4 = [[重复购买可叠加天数]],
			price = 218,
			original_price = 284,
			gift_id = 5,
		},
}
return shop_vip