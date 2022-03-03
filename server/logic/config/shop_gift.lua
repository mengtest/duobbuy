--[[
	类型, 名称, 货物, 描述1, 描述2, 价格, 展示图标, 排序, 礼包ID, 所需礼包
	id, name, goods, desc1, desc2, price, icon, rank, gift_id, need_gift
]]
local shop_gift = {
	[201] = {
			id = 201,
			name = [[金刚怒吼礼包]],
			goods = {{goodsId=1,amount=580000},{gunId=5}},
			desc1 = [[]],
			desc2 = [[<font outline=#000000,1 >金刚怒吼+58W金币（限购一次）</font>]],
			price = 168,
			gift_id = 0,
			need_gift = 0,
		},
	[202] = {
			id = 202,
			name = [[极光魅影礼包]],
			goods = {{goodsId=1,amount=1080000},{gunId=3}},
			desc1 = [[]],
			desc2 = [[<font outline=#000000,1 >极光魅影+108W金币（限购一次）</font>]],
			price = 298,
			gift_id = 0,
			need_gift = 0,
		},
}
return shop_gift