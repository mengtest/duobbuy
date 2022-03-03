local taskDb = {}
local taskConst = require("task.task_const")
local TaskStepKey = taskConst.TaskStepKey
local TaskStatusKey = taskConst.TaskStatusKey
local TaskDayKey = taskConst.TaskDayKey

function taskDb.getDayTaskInfo(db, roleId, day)
	local ret = db.Task:findOne({roleId = roleId, day = day})
	return ret
end

function taskDb.setDayTaskInfo(db, roleId, day, info)
	local doc = {
        query = {roleId = roleId, day = day},
        update = {["$set"] = info},
        upsert = true,
    }

    db.Task:findAndModify(doc)
end

function taskDb.incrDayTaskStep(db, roleId, day, taskId, step)
	db.Task:update(
		{roleId = roleId, day = day},
		{["$inc"] = { [TaskStepKey .. taskId] = step }}
	)
end

function taskDb.setDayTaskStatus(db, roleId, day, taskId, status)
	db.Task:update(
		{roleId = roleId, day = day},
		{["$set"] = { [TaskStatusKey .. taskId] = status }}
	)
end

function taskDb.setDayFullStatus(db, roleId, day, status)
	db.Task:update(
		{roleId = roleId, day = day},
		{["$set"] = { [TaskDayKey] = status }}
	)
end


return taskDb