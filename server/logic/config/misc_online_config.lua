--[[
	兑换券类型, 名字, 在线时间, 奖励, 帮助
	type, name, online_time, award_info, help
]]
local misc_online_config = {
	[4] = {
			type = 4,
			name = [[Q币奖券签到]],
			online_time = 3600,
			award_info = {
{goodsId=1,amount=500},
{goodsId=1,amount=500},
{goodsId=1,amount=800},
{goodsId=1,amount=800},
{goodsId=1,amount=1000},
{goodsId=1,amount=1000},
{currencyId=201,rand={2,2},desc="2-10Q币"}
},
			help = [[在线领Q币]],
		},
	[6] = {
			type = 6,
			name = [[Q币奖券签到]],
			online_time = 3600,
			award_info = {
{goodsId=1,amount=500},
{goodsId=1,amount=500},
{goodsId=1,amount=800},
{goodsId=1,amount=800},
{goodsId=1,amount=1000},
{goodsId=1,amount=1000},
{currencyId=201,rand={5,5},desc="5-10Q币"}
},
			help = [[在线领Q币]],
		},
	[5] = {
			type = 5,
			name = [[话费奖券签到]],
			online_time = 3600,
			award_info = {
{goodsId=1,amount=500},
{goodsId=1,amount=500},
{goodsId=1,amount=800},
{goodsId=1,amount=800},
{goodsId=1,amount=1000},
{goodsId=1,amount=1000},
{currencyId=202,rand={2,2},desc="2-100话费"}
},
			help = [[在线领话费]],
		},
	[7] = {
			type = 7,
			name = [[话费奖券签到]],
			online_time = 3600,
			award_info = {
{goodsId=1,amount=500},
{goodsId=1,amount=500},
{goodsId=1,amount=800},
{goodsId=1,amount=800},
{goodsId=1,amount=1000},
{goodsId=1,amount=1000},
{currencyId=202,rand={5,5},desc="5-100话费"}
},
			help = [[在线领话费]],
		},
}
return misc_online_config