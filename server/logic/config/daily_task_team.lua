local dailyTaskGroup = {}
local dailyTaskType = {}
local dailyTask = require("config.daily_task")

for _,info in pairs(dailyTask) do
	local groupId = info.group
	local taskType = info.type
	local taskId = info.id

	if not dailyTaskGroup[groupId] then
		dailyTaskGroup[groupId] = {}
	end
	table.insert(dailyTaskGroup[groupId], taskId)

	if not dailyTaskType[taskType] then
		dailyTaskType[taskType] = {}
	end
	table.insert(dailyTaskType[taskType], taskId)
end

local team = {
	group = dailyTaskGroup,
	taskType = dailyTaskType,
}

return team