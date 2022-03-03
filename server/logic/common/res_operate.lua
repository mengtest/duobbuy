local logger       	= require("log")
local context      	= require("common.context")
local roleCtrl     	= require("role.role_ctrl")
local roleConst 	= require("role.role_const")
local math = math
local resOperate   = {}

--[[
	发放单个物品或属性
	@param source 		道具操作来源
	@param partnerList 	要添加该资源的伙伴ID列表(可选，当添加的资源为伙伴类型资源时需要指定该参数)
]]
function resOperate.send(roleId, goodsId, amount, source, ...)
	if not context.agent then
		local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
		if not agentAdress then
			return SystemError.argument
		end
		return context.callS2S(agentAdress, "doResOperate", "send", roleId, goodsId, amount, source, ...)
	end
	return roleCtrl.addRes(roleId, goodsId, amount, source, ...)
end

--[[
	发放炮塔
	@param source 		道具操作来源
	@param partnerList 	要添加该资源的伙伴ID列表(可选，当添加的资源为伙伴类型资源时需要指定该参数)
]]
function resOperate.addGun(roleId, gunId, source, ...)
	if not context.agent then
		local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
		if not agentAdress then
			return SystemError.argument
		end
		return context.callS2S(agentAdress, "doResOperate", "addGun", roleId, gunId, source, ...)
	end
	return roleCtrl.addGun(roleId, gunId, source, ...)
end

--[[
	发放道具列表
	@param goodsList 	发放的道具列表
		goodsList = {
			{goodsId = xxx, amount = xxx},
			...
		}
	@param source 		道具操作来源
]]
function resOperate.sendList(roleId, goodsList, source)
	if not context.agent then
		local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
		if not agentAdress then
			return SystemError.argument
		end
		return context.callS2S(agentAdress, "doResOperate", "sendList", roleId, goodsList, source)
	end
	local ec = SystemError.success
	if goodsList == nil or table.empty(goodsList) then
		return ec
	end

	--发放资源
	for _, res in pairs(goodsList) do
		if res.goodsId then
			roleCtrl.addRes(roleId, res.goodsId, res.amount, source)
		elseif res.gunId then
			roleCtrl.addGun(roleId, res.gunId, source, res.time)
		elseif res.currencyId then
			-- roleCtrl.addCurrency(roleId, res.currencyId, res.amount, source)
		end
	end

	return ec
end

--[[
	扣除物品
	@param goodsList 	要扣除的道具列表
		goodsList = {
			{goodsId = xxx, amount = xxx},
			...
		}
	@param source 		道具操作来源
	@param sceneType 	使用道具所在场景类型
	注：amount字段请保证为正数
]]
function resOperate.costList(roleId, goodsList, source)
	if not context.agent then
		local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
		if not agentAdress then
			return SystemError.argument
		end
		return context.callS2S(agentAdress, "doResOperate", "costList", roleId, goodsList, source)
	end

	--资源数量检查
	for _, res in pairs(goodsList) do
		local resNum = roleCtrl.getResNum(roleId, res.goodsId)
		if resNum < math.abs(res.amount) then
			if res.goodsId == roleConst.GOLD_ID then
				return GameError.goldNotEnough
			elseif res.goodsId == roleConst.TREASURE_ID then
				return GameError.treasureNotEnough
			else
				return GameError.resourceNotEnough
			end
		end
	end

	-- 扣除资源
	for _, res in pairs(goodsList) do
		roleCtrl.addRes(roleId, res.goodsId, -math.abs(res.amount), source)
	end

	return SystemError.success
end

--[[
	扣除金币
	@param amount		扣除数量
	@param source 		道具操作来源
	注：amount字段请保证为正数
]]
function resOperate.costGold(roleId, amount, source)
	if not context.agent then
		local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
		if not agentAdress then
			return SystemError.argument
		end
		return context.callS2S(agentAdress, "doResOperate", "costGold", roleId, amount, source)
	end

	return roleCtrl.addRes(roleId, roleConst.GOLD_ID, -math.abs(amount), source)
end

--[[
	扣除夺宝卡
	@param amount		扣除数量
	@param source 		道具操作来源
	注：amount字段请保证为正数
]]
function resOperate.costTreasure(roleId, amount, source)
	if not context.agent then
		local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
		if not agentAdress then
			return SystemError.argument
		end
		return context.callS2S(agentAdress, "doResOperate", "costTreasure", roleId, amount, source)
	end

	return roleCtrl.addRes(roleId, roleConst.TREASURE_ID, -math.abs(amount), source)
end

-- 判断资源是否足够
function resOperate.isResEnough(roleId, goodsId, amount)
	if not context.agent then
		local agentAdress = context.callS2S(SERVICE.AGENT, "getAddressOfRole", roleId)
		if not agentAdress then
			return SystemError.argument
		end
		return context.callS2S(agentAdress, "doResOperate", "isResEnough", roleId, goodsId, amount)
	end
	local resNum = roleCtrl.getResNum(roleId, goodsId)
	if resNum < amount then
		if goodsId == roleConst.GOLD_ID then
			return GameError.goldNotEnough
		elseif goodsId == roleConst.TREASURE_ID then
			return GameError.treasureNotEnough
		else
			return GameError.resourceNotEnough
		end
	end
	
	return SystemError.success
end

return resOperate