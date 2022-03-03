local resOperate = require("common.res_operate")
local dbHelp = require("common.db_help")
local context = require("common.context")
local configDb = require("config.config_db")
local boxConfig = configDb.box
local roleConst = require("role.role_const")
local roleCtrl = require("role.role_ctrl")
local logConst = require("game.log_const")
local shopGoldConfig = require("config.shop_gold")

local boxCtrl = {}
local MAX_CHARGE_NUM = 1500 --无限制开启充值金额

-- 开宝箱
function boxCtrl.open(roleId, boxId)
	local conf = boxConfig[boxId]
	if not conf then
		return SystemError.argument
	end
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	local openNum = dbHelp.call("box.getOpenNum", roleId, boxId)
	if roleInfo.chargeNum < MAX_CHARGE_NUM and openNum <= 0 then
		return BoxError.noOpenNum
	end

	local ec = resOperate.costGold(roleId, conf.cost, logConst.boxCost)
	if ec ~= SystemError.success then
		return ec
	end
	local reward = conf.reward
	local luckyNum
	if math.rand() <= 0.75 then
		luckyNum = math.rand(reward[1], (reward[1] + reward[2]) / 2)
	else
		luckyNum = math.rand((reward[1] + reward[2]) / 2, reward[2])
	end
	if roleInfo.notFishGold < 0 then
		luckyNum = math.rand(reward[1], math.ceil((2 * reward[1] + reward[2]) / 3))
	end
	dbHelp.call("box.incrOpenNum", roleId, boxId, -1)
	resOperate.send(roleId, roleConst.TREASURE_ID, luckyNum, logConst.boxGet)
	
	-- context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 4, words = {roleInfo.nickname, luckyNum}})
	return ec, luckyNum
end

-- 获取界面信息
function boxCtrl.getInfo(roleId)
	local result = {}
	for _,conf in ipairs(boxConfig) do
		local openNum = dbHelp.call("box.getOpenNum", roleId, conf.id)
		result[#result+1] = openNum
	end
	local roleInfo = roleCtrl.getRoleInfo(roleId)
	return result, MAX_CHARGE_NUM, roleInfo.chargeNum
end

-- 
function boxCtrl.onLogin(roleId)
	local initFlag = dbHelp.call("box.getNumInitFlag", roleId)
	if not initFlag then
		local roleInfo = roleCtrl.getRoleInfo(roleId)
		if roleInfo.chargeNum < MAX_CHARGE_NUM then
			local addNums = {}
			for shopIndex, conf in pairs(shopGoldConfig) do
				local joinNum = dbHelp.call("charge.getRoleChargeIndexNum", roleId, shopIndex)
				if joinNum > 0 then
					for boxId,num in pairs(conf.treasure) do
						if num > 0 then
							addNums[boxId] = (addNums[boxId] or 0) + num * joinNum
						end
					end
				end
			end

			for boxId,num in pairs(addNums) do
				dbHelp.call("box.incrOpenNum", roleId, boxId, num)
			end
		end
		dbHelp.call("box.setInitFlag", roleId)
	end
end

return boxCtrl