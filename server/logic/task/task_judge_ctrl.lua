local taskConst = require("task.task_const")
local TaskType = taskConst.TaskType
local configDb = require("config.config_db")
local dailyTaskConfig = configDb.daily_task

local taskJudgeCtrl = {}

function taskJudgeCtrl.resChange(taskId, amount, resId)
	local condition = dailyTaskConfig[taskId].condition or {}
	if #condition == 0 then
		return amount
	end
	local needResId = condition[1]
	if needResId == resId then
		return amount
	else
		return 0
	end
end

function taskJudgeCtrl.fishShot(taskId, amount, fishId)
	local condition = dailyTaskConfig[taskId].condition or {}
	if #condition == 0 then
		return amount
	end
	local needResId = condition[1]
	if fishId == needResId then
		return amount
	else
		return 0
	end
end

function taskJudgeCtrl.arenaJoin(taskId, amount, roomType)
	local condition = dailyTaskConfig[taskId].condition or {}
	if #condition == 0 then
		return amount
	end
	local needRoomType = condition[1]
	if roomType == needRoomType then
		return amount
	else
		return 0
	end
end

function taskJudgeCtrl.getFuncList()
	local funcs = {}
	funcs[ TaskType.GoldCost] = taskJudgeCtrl.resChange
	funcs[ TaskType.TreasureGet] = taskJudgeCtrl.resChange
	funcs[ TaskType.FishShot] = taskJudgeCtrl.fishShot
	funcs[ TaskType.ArenaJoin] = taskJudgeCtrl.arenaJoin
	return funcs
end

return taskJudgeCtrl