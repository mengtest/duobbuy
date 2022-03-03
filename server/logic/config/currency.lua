--[[
	类型, 属性名称, 名称, 描述, 数量, 资源, 资源大图
	id, attrName, name, desc, amount, icon, iconBig
]]
local currency = {
	[100] = {
			id = 100,
			attrName = [[qb]],
			name = [[2个Q币]],
			desc = [[2个Q币]],
			amount = 2,
		},
	[101] = {
			id = 101,
			attrName = [[话费]],
			name = [[2元话费]],
			desc = [[2-100元话费]],
			amount = 2,
		},
	[200] = {
			id = 200,
			attrName = [[兑换券]],
			name = [[兑换券]],
			desc = [[兑换券]],
			amount = 1,
		},
	[201] = {
			id = 201,
			attrName = [[Q币]],
			name = [[Q币]],
			desc = [[Q币]],
			amount = 1,
		},
	[202] = {
			id = 202,
			attrName = [[话费]],
			name = [[话费]],
			desc = [[话费]],
			amount = 1,
		},
}
return currency