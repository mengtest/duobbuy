local EventCode = {
	KILL_MONSTER 		= 0x0001, 		-- 杀怪
	ADD_ITEM 			= 0x0002, 		-- 获得新物品
	KILL_ROLE	 		= 0x0003, 		-- 击杀玩家
	USE_ITEM			= 0x0004,		-- 使用道具
	TASK_STATUS_CHANGE 	= 0x0005,		-- 任务状态变化
	ROLE_LEVEL_UP 		= 0x0006,		-- 角色升级
	COLLECT				= 0x0007,		-- 成功完成采集操作
	ENTER_AREA          = 0x0008,		-- 进入区域
	EQUIP_UP 			= 0x0009,		-- 装备升级
	TALENT_UP			= 0x000a,		-- 天赋升级
	MONSTER_DEAD 		= 0x000b,		-- 怪物死亡
	ROLE_DEAD 			= 0x000e,		-- 玩家死亡
	COPY_OVER			= 0x000f,		-- 副本通关
}

return EventCode
