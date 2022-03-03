local ProgressHelper = {}

function ProgressHelper.increase(srcData, id, num)
	local modify = false
	if id then
		for k, data in pairs(srcData) do
			if data.id == id then
				data.num = data.num + num
				modify = true
			end
		end
	else
		srcData.num = srcData.num + num
		modify = true
	end

	return modify
end

function ProgressHelper.decrease(srcData, id, num)
	local modify = false
	if id then
		for k, data in pairs(srcData) do
			if data.id == id then
				data.num = data.num - num
				modify = true
			end
		end
	else
		srcData.num = srcData.num - num
		modify = true
	end

	return modify
end

--检查进度是否完成 
--@param target 	目标进度 {{id, num}, {id, num}, ...}
--@param curPro 	当前进度 {{id=xx, num=xx}, {id=xx, num=xx}, ...}
function ProgressHelper.checkComplete(target, curPro)
	for _, tar in pairs(target) do
		local found = false
		for _, pro in pairs(curPro) do
			if tar[1] == pro.id then
				found = true
				if tar[2] > pro.num then
					return false
				end
			end
		end

		assert(found, "任务进度不匹配")
	end

	return true
end

return ProgressHelper



