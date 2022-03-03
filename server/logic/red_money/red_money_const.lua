local redMoneyConst = {
	activityId = 4,
	numMap = {
		{min = 100, max = 200, weight = 85},
		{min = 200, max = 500, weight = 95},
		{min = 500, max = 1000, weight = 98},
		{min = 1000, max = 2000, weight = 100},
	},
	step = 10,
	joinNum = 8,
	wdays = {1,2,3,4,5,6,7},
	stepSec = {10 * 60, 12 * 60},

	ActivePeriodList = 
	{
		-- 每天 11:00-13:00
		{
			wdays = {2,3,4,5,6,7,1},	-- 星期天为1
			startHour = {hour = 11, min = 0, sec = 0},
			endHour = {hour = 13, min = 0, sec = 0},
		},
		-- 每天 17:00-18:00
		{
			wdays = {2,3,4,5,6,7,1},	-- 星期天为1
			startHour = {hour = 17, min = 0, sec = 0},
			endHour = {hour = 18, min = 0, sec = 0},
		},
	}
}

return redMoneyConst