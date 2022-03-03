local taskCtrl = require("task.task_ctrl")
local taskImpl = {}

function taskImpl.getTaskList(roleId)
	local info, state = taskCtrl.getTaskList(roleId)
	return SystemError.success, {tasks = info, totalState = state}	
end

function taskImpl.receiveAward(roleId, taskId)
	return taskCtrl.receiveAward(roleId, taskId)
end

function taskImpl.receiveTotalAward(roleId)
	return taskCtrl.receiveTotalAward(roleId)
end

return taskImpl