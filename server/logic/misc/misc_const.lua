local MiscConst = {}

MiscConst.AwardStatus = {
	RECEIVED 			= 1, 	-- 已经领取
	CAN_RECEIVE 		= 2,	-- 可领取
	COUNT_DOWN 			= 3,	-- 倒计时
	CAN_NOT_RECEIVE 	= 4,	-- 不可领取
}

MiscConst.expireTime 	= 86400 * 3	-- 完成之后显示时间

return MiscConst