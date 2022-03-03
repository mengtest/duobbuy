local EventCode 		= require("common.event_code")
local taskCtrl 			= require("task.task_ctrl")
local activityCtrl 		= require("activity.activity_ctrl")
local SystemOpenCtrl 	= require("system_open.system_open_ctrl")

local EventListener = {}
function EventListener.killMonsterListener(event, monsterId, num, sceneId)
	taskCtrl.eventHandler(event, monsterId, num, sceneId)
	activityCtrl.eventHandler(event,monsterId,num)
end

--监听物品变化
function EventListener.addItemListener(event, goodsId, num)
	taskCtrl.eventHandler(event, goodsId, num)
end

--监听道具的使用
function EventListener.useItemListener(event, goodsId, num)
	taskCtrl.eventHandler(event, goodsId, num)
end

--任务状态变化监听器
function EventListener.taskStatusChangeListener(event, taskId, status)
	SystemOpenCtrl.eventHandler(event, taskId, status)
end

--角色升级监听
function EventListener.roleLevelUpListner(event, oldlevel, newLevel)
	SystemOpenCtrl.eventHandler(event, oldlevel, newLevel)
end

--采集事件监听
function EventListener.collectListner(event, collectId, num)
	taskCtrl.eventHandler(event, collectId, num)
end

function EventListener.enterAreaListener(event, areaId, num, sceneId)
	taskCtrl.eventHandler(event, areaId, num, sceneId)
end

function EventListener.equipUpListener(event, partType, num, oldLv, newLv)
	taskCtrl.eventHandler(event, partType, num, oldLv, newLv)
end

function EventListener.talentUpListener(event,talentSubType,num,newLv)
	taskCtrl.eventHandler(event,talentSubType,num,newLv)
end

function EventListener.copyOverListener(event, copyId, num)
	taskCtrl.eventHandler(event, copyId, num)
end

function EventListener.onLogin(roleId)
	dispatcher:addEventListener(EventCode.KILL_MONSTER, nil, EventListener.killMonsterListener)
	dispatcher:addEventListener(EventCode.ADD_ITEM, nil, EventListener.addItemListener)
	dispatcher:addEventListener(EventCode.USE_ITEM, nil, EventListener.useItemListener)
	dispatcher:addEventListener(EventCode.TASK_STATUS_CHANGE, nil, EventListener.taskStatusChangeListener)
	dispatcher:addEventListener(EventCode.ROLE_LEVEL_UP, nil, EventListener.roleLevelUpListner)
	dispatcher:addEventListener(EventCode.COLLECT, nil, EventListener.collectListner)
	dispatcher:addEventListener(EventCode.ENTER_AREA, nil, EventListener.enterAreaListener)
	dispatcher:addEventListener(EventCode.EQUIP_UP, nil, EventListener.equipUpListener)
	dispatcher:addEventListener(EventCode.TALENT_UP, nil, EventListener.talentUpListener)
	dispatcher:addEventListener(EventCode.COPY_OVER, nil, EventListener.copyOverListener)
end

return EventListener