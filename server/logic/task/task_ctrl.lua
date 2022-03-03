local roleCtrl = require("role.role_ctrl")
local roleEvent = require("role.role_event")
local taskConst = require("task.task_const")
local TaskStatus = taskConst.TaskStatus
local TaskType = taskConst.TaskType
local TotalStatus = taskConst.TotalStatus
local TaskStepKey = taskConst.TaskStepKey
local TaskStatusKey = taskConst.TaskStatusKey
local dbHelp = require("common.db_help")
local configDb = require("config.config_db")
local dailyTaskConfig = configDb.daily_task
local dailyTaskTeamConfig = configDb.daily_task_team
local activityConfig = configDb.activity
local activityAward = activityConfig[taskConst.ActivityId].params.award
local dailyTaskGroupConfig = dailyTaskTeamConfig.group
local dailyTaskTypeConfig = dailyTaskTeamConfig.taskType

local context = require("common.context")
local logConst = require("game.log_const")
local resOperate = require("common.res_operate")
local taskJudgeCtrl = require("task.task_judge_ctrl")
local taskCtrl = {}

local taskCache = {}
local conditionFunc = {}

local function getDayFlag(sec)
	local sec = sec or os.time()
	return os.date("%Y%m%d", sec)
end

function taskCtrl.getTaskCache(roleId, day)
	if taskCache[roleId] and taskCache[roleId][day] then
		return taskCache[roleId][day]
	end
end

function taskCtrl.setTaskCache(roleId, day, info)
	if not taskCache[roleId] then
		taskCache[roleId] = {}
	end
	taskCache[roleId][day] = info
end

function taskCtrl.getTaskInfo(roleId)
	local day = getDayFlag()
	local dayTaskCacheInfo = taskCtrl.getTaskCache(roleId, day)
	if dayTaskCacheInfo then
		return dayTaskCacheInfo, day
	end
	local dayTaskInfo = dbHelp.call("task.getDayTaskInfo", roleId, day)
	if not dayTaskInfo then
		dayTaskInfo = taskCtrl.initTaskInfo(roleId, day)
	end
	taskCtrl.setTaskCache(roleId, day, dayTaskInfo)
	return dayTaskInfo, day
end

function taskCtrl.initTaskInfo(roleId, day)
	local dailyTaskIds = {}
	for _,taskIds in pairs(dailyTaskGroupConfig) do
		local taskIndex = math.random(1, #taskIds)
		local taskId = taskIds[taskIndex]
		dailyTaskIds[#dailyTaskIds+1] = taskId
	end
	local taskInfo = {}
	taskInfo.dailyTaskIds = dailyTaskIds

	for _,taskId in pairs(dailyTaskIds) do
		taskInfo[ TaskStepKey .. taskId ] = 0
	end
	-- dump(taskInfo)
	dbHelp.send("task.setDayTaskInfo", roleId, day, taskInfo)
	return taskInfo
end

function taskCtrl.incrTaskStep(roleId, taskType, step, ...)
	local taskInfos, day = taskCtrl.getTaskInfo(roleId)
	local dailyTaskIds = taskInfos.dailyTaskIds

	local taskIdsInType = dailyTaskTypeConfig[taskType] or {}
	for _, taskId in pairs(taskIdsInType) do
		if table.find(dailyTaskIds, taskId) then
			local taskStatus = taskInfos[ TaskStatusKey .. taskId ]
			if not taskStatus or taskStatus == TaskStatus.canNot then
				local incrStep = taskCtrl.judgeCondition(taskId, step, ...)
				if incrStep ~= 0 then
					local updateInfo = {}
					local curStep = (taskInfos[ TaskStepKey .. taskId ] or 0) + incrStep
					if curStep >= dailyTaskConfig[taskId].num then
						curStep = dailyTaskConfig[taskId].num
					end
					taskInfos[ TaskStepKey .. taskId ] = curStep
					updateInfo[ TaskStepKey .. taskId ] = curStep
					if curStep >= dailyTaskConfig[taskId].num then
						taskInfos[ TaskStatusKey .. taskId ] = TaskStatus.canGet
						updateInfo[ TaskStatusKey .. taskId ] = TaskStatus.canGet
					end
					-- dump(updateInfo)
					-- dbHelp.send("task.setDayTaskInfo", roleId, day, updateInfo)

					local updateStatue = taskInfos[ TaskStatusKey .. taskId ] or TaskStatus.canNot
					context.sendS2C(roleId, M_Task.handleTaskUpdate, {taskId = taskId, finishedCount = curStep, state = updateStatue})
				end
			end
		end
	end
end

function taskCtrl.registerConditionJudgeFunc(taskType, func)
	conditionFunc[taskType] = func
end

function taskCtrl.judgeCondition(taskId, step, ...)
	local taskType = dailyTaskConfig[taskId].type
	local func = conditionFunc[taskType]
	if not func then
		return step
	end
	return func(taskId, step, ...)
end

local judgeFuncs = taskJudgeCtrl.getFuncList()
for taskType, func in pairs(judgeFuncs) do
	taskCtrl.registerConditionJudgeFunc(taskType, func)
end

--------------------------------------------------------------------------

function taskCtrl.getTaskList(roleId)
	local taskInfos, day = taskCtrl.getTaskInfo(roleId)
	local taskIds = taskInfos.dailyTaskIds
	local result = {}
	local finishTaskNum = 0
	for _,taskId in pairs(taskIds) do
		local taskStatus = taskInfos[ TaskStatusKey .. taskId ]
		if not taskStatus then
			taskStatus = TaskStatus.canNot
		end
		if taskStatus == TaskStatus.canGet or taskStatus == TaskStatus.hadGet then
			finishTaskNum = finishTaskNum + 1
		end
		local finishedCount = taskInfos[ TaskStepKey .. taskId ] or 0
		result[#result+1] = {
			taskId = taskId,
			state = taskStatus,
			finishedCount = finishedCount,
		}
	end

	local totalState = taskInfos[taskConst.TaskDayKey]
	if not totalState then
		if finishTaskNum >= #taskIds then
			totalState = TotalStatus.canGet
		else
			totalState = TotalStatus.canNot
		end
	end

	return result, totalState, taskInfos, day
end

function taskCtrl.receiveAward(roleId, taskId)
	local taskInfos, day = taskCtrl.getTaskInfo(roleId)
	local taskStatus = taskInfos[ TaskStatusKey .. taskId ]
	if not taskStatus or taskStatus == TaskStatus.canNot then
		return TaskError.canNotGet
	end
	if taskStatus == TaskStatus.hadGet then
		return TaskError.hadGet
	end
	taskInfos[ TaskStatusKey .. taskId ] = TaskStatus.hadGet
	dbHelp.call("task.setDayTaskStatus", roleId, day, taskId, TaskStatus.hadGet)
	local awardInfo = dailyTaskConfig[taskId].award
	resOperate.send(roleId, awardInfo.goodsId, awardInfo.amount, logConst.dailyTaskGet)
	return SystemError.success
end

function taskCtrl.receiveTotalAward(roleId)
	local _, state, taskInfos, day = taskCtrl.getTaskList(roleId)
	if not state or state == TotalStatus.canNot then
		return TaskError.canNotGet
	end
	if state == TotalStatus.hadGet then
		return TaskError.hadGet
	end
	taskInfos[ taskConst.TaskDayKey ] = TotalStatus.hadGet
	dbHelp.call("task.setDayFullStatus", roleId, day, TotalStatus.hadGet)
	resOperate.addGun(roleId, activityAward.gunId, logConst.dailyTaskTotalGet, activityAward.time)
	return SystemError.success
end

---------------------------------------------------------------------

function taskCtrl.handleResChange(roleId, resGoodsId, amount, source)
	if amount > 0 and source == logConst.shotGet then
		taskCtrl.incrTaskStep(roleId, TaskType.TreasureGet, amount, resGoodsId)
	elseif amount < 0 and source == logConst.shotCost then
		taskCtrl.incrTaskStep(roleId, TaskType.GoldCost, -amount, resGoodsId)
	end
end

function taskCtrl.onLogin(roleId)
	roleEvent.registerResChangeEvent(taskCtrl.handleResChange)
end

function taskCtrl.onLogout(roleId)
	local taskInfos, day = taskCtrl.getTaskInfo(roleId)
	dbHelp.send("task.setDayTaskInfo", roleId, day, taskInfos)
end

return taskCtrl