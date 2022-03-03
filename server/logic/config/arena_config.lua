--[[
	名字, 竞技场类型, 级别, 保证金, 入场费, 最小炮台倍数, 初始子弹数, 奖励, 积分
	name, type, level, money, bet, minGunLevel, bullet, award, points
]]
local arena_config = {
 {
		name = [[夺宝卡初级场]],
		type = 2,
		level = 1,
		money = {goodsId=1,amount=1},
		bet = {goodsId=2,amount=5},
		minGunLevel = 100,
		bullet = 50000,
		award = {{goodsId=2,amount=19}},
		points = {19,0,0,0},
	},
 {
		name = [[夺宝卡中级场]],
		type = 2,
		level = 2,
		money = {goodsId=1,amount=1},
		bet = {goodsId=2,amount=10},
		minGunLevel = 500,
		bullet = 250000,
		award = {{goodsId=2,amount=38}},
		points = {38,0,0,0},
	},
 {
		name = [[夺宝卡高级场]],
		type = 2,
		level = 3,
		money = {goodsId=1,amount=1},
		bet = {goodsId=2,amount=50},
		minGunLevel = 1000,
		bullet = 500000,
		award = {{goodsId=2,amount=190}},
		points = {190,0,0,0},
	},
 {
		name = [[夺宝卡大师场]],
		type = 2,
		level = 4,
		money = {goodsId=1,amount=1},
		bet = {goodsId=2,amount=100},
		minGunLevel = 2000,
		bullet = 1000000,
		award = {{goodsId=2,amount=380}},
		points = {380,0,0,0},
	},
}
return arena_config