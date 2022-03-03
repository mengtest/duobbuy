--[[
	类型, 轮次, 充值金额, 奖励组
	id, cycle, amount, group
]]
local egg_recharge = {
	[1] = {
			id = 1,
			cycle = 1,
			amount = 20,
			group = 1,
		},
	[2] = {
			id = 2,
			cycle = 1,
			amount = 50,
			group = 1,
		},
	[3] = {
			id = 3,
			cycle = 1,
			amount = 100,
			group = 1,
		},
	[4] = {
			id = 4,
			cycle = 1,
			amount = 200,
			group = 1,
		},
	[5] = {
			id = 5,
			cycle = 1,
			amount = 400,
			group = 1,
		},
	[6] = {
			id = 6,
			cycle = 1,
			amount = 900,
			group = 1,
		},
	[7] = {
			id = 7,
			cycle = 1,
			amount = 1700,
			group = 1,
		},
	[8] = {
			id = 8,
			cycle = 1,
			amount = 3000,
			group = 1,
		},
	[9] = {
			id = 9,
			cycle = 1,
			amount = 5000,
			group = 2,
		},
	[10] = {
			id = 10,
			cycle = 2,
			amount = 5040,
			group = 3,
		},
	[11] = {
			id = 11,
			cycle = 2,
			amount = 5100,
			group = 3,
		},
	[12] = {
			id = 12,
			cycle = 2,
			amount = 5200,
			group = 3,
		},
	[13] = {
			id = 13,
			cycle = 2,
			amount = 5400,
			group = 3,
		},
	[14] = {
			id = 14,
			cycle = 2,
			amount = 5800,
			group = 3,
		},
	[15] = {
			id = 15,
			cycle = 2,
			amount = 6800,
			group = 3,
		},
	[16] = {
			id = 16,
			cycle = 2,
			amount = 8400,
			group = 3,
		},
	[17] = {
			id = 17,
			cycle = 2,
			amount = 11000,
			group = 3,
		},
	[18] = {
			id = 18,
			cycle = 2,
			amount = 15000,
			group = 4,
		},
	[19] = {
			id = 19,
			cycle = 3,
			amount = 15040,
			group = 5,
		},
	[20] = {
			id = 20,
			cycle = 3,
			amount = 15100,
			group = 5,
		},
	[21] = {
			id = 21,
			cycle = 3,
			amount = 15200,
			group = 5,
		},
	[22] = {
			id = 22,
			cycle = 3,
			amount = 15400,
			group = 5,
		},
	[23] = {
			id = 23,
			cycle = 3,
			amount = 15800,
			group = 5,
		},
	[24] = {
			id = 24,
			cycle = 3,
			amount = 16800,
			group = 5,
		},
	[25] = {
			id = 25,
			cycle = 3,
			amount = 18400,
			group = 5,
		},
	[26] = {
			id = 26,
			cycle = 3,
			amount = 21000,
			group = 5,
		},
	[27] = {
			id = 27,
			cycle = 3,
			amount = 25000,
			group = 6,
		},
	[28] = {
			id = 28,
			cycle = 4,
			amount = 25040,
			group = 7,
		},
	[29] = {
			id = 29,
			cycle = 4,
			amount = 25100,
			group = 7,
		},
	[30] = {
			id = 30,
			cycle = 4,
			amount = 25200,
			group = 7,
		},
	[31] = {
			id = 31,
			cycle = 4,
			amount = 25400,
			group = 7,
		},
	[32] = {
			id = 32,
			cycle = 4,
			amount = 25800,
			group = 7,
		},
	[33] = {
			id = 33,
			cycle = 4,
			amount = 26800,
			group = 7,
		},
	[34] = {
			id = 34,
			cycle = 4,
			amount = 28400,
			group = 7,
		},
	[35] = {
			id = 35,
			cycle = 4,
			amount = 31000,
			group = 7,
		},
	[36] = {
			id = 36,
			cycle = 4,
			amount = 35000,
			group = 8,
		},
	[37] = {
			id = 37,
			cycle = 5,
			amount = 35040,
			group = 9,
		},
	[38] = {
			id = 38,
			cycle = 5,
			amount = 35100,
			group = 9,
		},
	[39] = {
			id = 39,
			cycle = 5,
			amount = 35200,
			group = 9,
		},
	[40] = {
			id = 40,
			cycle = 5,
			amount = 35400,
			group = 9,
		},
	[41] = {
			id = 41,
			cycle = 5,
			amount = 35800,
			group = 9,
		},
	[42] = {
			id = 42,
			cycle = 5,
			amount = 36800,
			group = 9,
		},
	[43] = {
			id = 43,
			cycle = 5,
			amount = 38400,
			group = 9,
		},
	[44] = {
			id = 44,
			cycle = 5,
			amount = 41000,
			group = 9,
		},
	[45] = {
			id = 45,
			cycle = 5,
			amount = 45000,
			group = 10,
		},
	[46] = {
			id = 46,
			cycle = 6,
			amount = 45040,
			group = 11,
		},
	[47] = {
			id = 47,
			cycle = 6,
			amount = 45100,
			group = 11,
		},
	[48] = {
			id = 48,
			cycle = 6,
			amount = 45200,
			group = 11,
		},
	[49] = {
			id = 49,
			cycle = 6,
			amount = 45400,
			group = 11,
		},
	[50] = {
			id = 50,
			cycle = 6,
			amount = 45800,
			group = 11,
		},
	[51] = {
			id = 51,
			cycle = 6,
			amount = 46800,
			group = 11,
		},
	[52] = {
			id = 52,
			cycle = 6,
			amount = 48400,
			group = 11,
		},
	[53] = {
			id = 53,
			cycle = 6,
			amount = 51000,
			group = 11,
		},
	[54] = {
			id = 54,
			cycle = 6,
			amount = 55000,
			group = 12,
		},
	[55] = {
			id = 55,
			cycle = 7,
			amount = 55040,
			group = 13,
		},
	[56] = {
			id = 56,
			cycle = 7,
			amount = 55100,
			group = 13,
		},
	[57] = {
			id = 57,
			cycle = 7,
			amount = 55200,
			group = 13,
		},
	[58] = {
			id = 58,
			cycle = 7,
			amount = 55400,
			group = 13,
		},
	[59] = {
			id = 59,
			cycle = 7,
			amount = 55800,
			group = 13,
		},
	[60] = {
			id = 60,
			cycle = 7,
			amount = 56800,
			group = 13,
		},
	[61] = {
			id = 61,
			cycle = 7,
			amount = 58400,
			group = 13,
		},
	[62] = {
			id = 62,
			cycle = 7,
			amount = 61000,
			group = 13,
		},
	[63] = {
			id = 63,
			cycle = 7,
			amount = 65000,
			group = 14,
		},
}
return egg_recharge