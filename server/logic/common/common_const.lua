local CommonConst = {}

CommonConst.RatioRange = 0.0001

--能否值
CommonConst.NO = 0
CommonConst.YES = 1

CommonConst.FormType = {
	NORMAL		= 1;	--普通形态
	MIDDLE 		= 2;	--中级形态
	SENIOR		= 3;	--高级形态
	ULTIMATE	= 4;	--究极形态
}

CommonConst.DAYTIME = 2;	-- 白天
CommonConst.NIGHT 	= 3;	-- 晚上

CommonConst.Weather = {
	NONE 	= 1, -- 无需求
	RAINY 	= 2, -- 下雨
	WIND 	= 3, -- 刮风
	THUNDER	= 4, -- 打雷
	FOG 	= 5, -- 大雾
}

-- 昼夜需求常量
CommonConst.DayAndNight = {
    IGNORE  = 0,    --无需求
    DAY     = 1,    --白天
    NIGHT   = 2,    --黑夜
}

CommonConst.TimingRule = {
	OFFLINE_DISAPPEAR	= 0, 	-- 下线道具消失
	OFFLINE 			= 1,	-- 下线也计时
	ONLINE	 			= 2,	-- 仅在线计时
}


return CommonConst