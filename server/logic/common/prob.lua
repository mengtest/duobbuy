local context      = require("common.context")
local configDb = require("config.config_db")
local TaskConst = require("task.task_const")
local dropList = configDb.drop_list
local dropGoods = configDb.drop_goods
local goodsConf = configDb.goods
local taskCtrl = nil
local prob = {}

local RuleType = {
	Round 		= 1,	-- 圆桌概率
	Linearity 	= 2,	-- 线性概率
}
local math = math


function prob.calcDropList(dropListId, roleId)
	local dropItems = {}
	local dropListInfo = dropList[dropListId]
	if dropListInfo.drop then
		for _, dropId in ipairs(dropListInfo.drop) do
			local goodsList = prob.calcDrop(dropGoods[dropId])
			table.merge(dropItems, goodsList)
		end
	end
	-- 任务掉落
	if dropListInfo.missionId and roleId then
		-- 判断是否agent 用来区别从哪里获得任务信息
		local isHasMission = false
		if not context.agent then
			local taskStatus = context.callAgentFunc(roleId, "task.task_ctrl", "getTaskStatus", roleId, dropListInfo.missionId)
            if taskStatus == TaskConst.Status.UNCOMPLETED then
				isHasMission = true
			end
		else
			if not taskCtrl then
				taskCtrl = require("task.task_ctrl")
			end
			local taskStatus = taskCtrl.getTaskStatus(roleId, dropListInfo.missionId)
			if taskStatus == TaskConst.Status.UNCOMPLETED then
				isHasMission = true
			end
		end
		if isHasMission then
			for _, dropId in ipairs(dropListInfo.missionDrop) do
				local goodsList = prob.calcDrop(dropGoods[dropId])
				table.merge(dropItems, goodsList)
			end
		end
	end

	return dropItems
end
--计算掉落的概率组
--@param dropConf 	掉落概率组配置
function prob.calcDrop(dropConf)
	local probGroup = {}
	for i = 1, 10 do
		local random = dropConf["random"..i]
		if random and random ~= 0 then
			local ret = {
				goodsId = dropConf["goodsId"..i],
				amount = dropConf["num"..i],
			}
			local prob = {
				random = random,
				ret = ret,
			}
			table.insert(probGroup, prob)
		else
			break
		end
	end

	if dropConf.randomRule1 == RuleType.Round then
		local retGoods = prob.calcRoundProb(probGroup)
		return retGoods
	elseif dropConf.randomRule1 == RuleType.Linearity then
		return prob.calcLinearityProb(probGroup, dropConf.maxNum)
	else
		assert(false)
	end
end

--[[
	计算圆桌概率
	@param  probGroup 	概率组
		{
			[1] = {
				random = xxx
				ret = { ... } --命中时返回的结果
			}
			...
		}
	@return ret  		结果
]]
function prob.calcRoundProb(probGroup)
	if table.nums(probGroup) == 0 then
		return
	end

	local maxProb = 0
	for k, prob in pairs(probGroup) do
		maxProb = maxProb + prob.random
	end
	local randNum = math.random(maxProb)
	local sum = 0
	for _, prob in ipairs(probGroup) do
		sum = sum + prob.random
		if randNum <= sum then
			local lastCount = prob.ret.amount
			local maxOverLay = goodsConf[prob.ret.goodsId].overlay
			if maxOverLay == 0 then maxOverLay = lastCount end
			local retList = {}
			while(lastCount > 0) do
				prob.ret.amount = lastCount > maxOverLay and maxOverLay or lastCount
				lastCount = lastCount - maxOverLay
				table.insert(retList, copy(prob.ret))
			end
			return retList
		end
	end
end

--[[
	计算线性概率
	@param  probGroup 	概率组
		{
			[1] = {
				random1 = xxx
				ret = { ... } --命中时返回的结果
			}
			...
		}
	@param  maxNum 		命中数量限制
	@return retList  	结果列表
]]
function prob.calcLinearityProb(probGroup, maxNum)
	if table.nums(probGroup) == 0 then
		return
	end

	local count = 0
	local retList = {}

	for _, prob in ipairs(probGroup) do
		if count >= maxNum then
			return retList
		end

		local randNum = math.random(10000)
		if randNum < prob.random then
			local lastCount = prob.ret.amount
			local maxOverLay = goodsConf[prob.ret.goodsId].overlay
			if maxOverLay == 0 then maxOverLay = lastCount end
			while(lastCount > 0) do
				prob.ret.amount = lastCount > maxOverLay and maxOverLay or lastCount
				lastCount = lastCount - maxOverLay
				table.insert(retList, copy(prob.ret))
			end
			count = count + 1
		end
	end

	return retList
end

return prob