local resOperate = require("common.res_operate")
local skynet = require("skynet")
local dbHelp = require("common.db_help")
local configDb = require("config.config_db")
local context = require("common.context")
local roleConst = require("role.role_const")
local roleCtrl = require("role.role_ctrl")
local fruitRateConf = configDb.fruitRate
local fruitRateData = fruitRateConf.data
local fruitRateTotal = fruitRateConf.total
local logConst = require("game.log_const")
local activityTotalConfig = configDb.activity

local fruitCtrl = {}
local fruitConst = require("fruit.fruit_const")

-- 随机数值
local function fruitRand()
	local luckyNum = math.rand(1, fruitRateTotal)
	local luckyInfo
	for _,v in ipairs(fruitRateData) do
		if luckyNum <= v.weight then
			luckyInfo = v
			break
		end
	end
	return luckyInfo
end

-- 转转
function fruitCtrl.roll(roleId)
	if true then 
		return ActivityError.notOpen
	end
	local freeNum = fruitCtrl.getFreeNum(roleId)
	if freeNum > 0 then
		fruitCtrl.incrUseFreeNum(roleId, 1)
	else
		local ec = resOperate.costGold(roleId, fruitConst.cost, logConst.fruitCost)
		if ec ~= SystemError.success then
			return ec
		end
	end
	local luckyNums = {}
	local awardInfos = {}
	for i=1, fruitConst.num do
		local randInfo = fruitRand()
		luckyNums[#luckyNums+1] = randInfo.id
		awardInfos[randInfo.id] = randInfo.award
	end

	local uniqueNum = table.unique(luckyNums)
	if #uniqueNum == 1 then
		local luckyNum = uniqueNum[1]
		local luckyAward = awardInfos[luckyNum]
		resOperate.send(roleId, roleConst.TREASURE_ID, luckyAward, logConst.fruitGet)
		local roleInfo = roleCtrl.getRoleInfo(roleId)
		skynet.timeout(200, function()
			context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 3, words = {roleInfo.nickname, luckyAward}})
		end)
	end

	return SystemError.success, luckyNums
end

-- 获取免费次数
function fruitCtrl.getFreeNum(roleId)
	local freeInfo = dbHelp.call("fruit.getFreeInfo", roleId)
	if not freeInfo then
		return 0
	end
	if not freeInfo.price then
		return 0
	end
	local totalFreeNum = math.floor(freeInfo.price / fruitConst.perPrice)
	local useFreeNum = freeInfo.useFreeNum or 0
	local freeNum = totalFreeNum - useFreeNum
	if freeNum < 0 then
		freeNum = 0
	end
	-- print("roleId:"..roleId.." freeNum:"..freeNum)
	return freeNum
end

-- 添加使用记录
function fruitCtrl.incrUseFreeNum(roleId, step)
	dbHelp.call("fruit.incrUseFreeNum", roleId, step)
end

return fruitCtrl