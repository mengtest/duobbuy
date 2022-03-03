local skynet  	= require("skynet")
local logger  	= require("log")
local json 		= require("json")
local md5    	= require("md5")
local context 	= require("common.context")
local dbHelp = require("common.db_help")
local activity  = require("service_base")
local language 	= require("language.language")

local queue = require("skynet.queue")
local queueEnter = queue()

local logConst = require("game.log_const")
local roleConst = require("role.role_const")
local serverId = skynet.getenv("serverId")

local activityStatus = require("activity.activity_const").activityStatus
local activityTime = require("activity.activity_const").activityTime
local conf 		= require("sharedata.corelib")
local markdirty = conf.host.markdirty
local activityConfig = {}


local command 	= activity.command
local reTrySec 	= 60

local initLotteryRank

local function updateConfigs()
	local agents = context.callS2S(SERVICE.AGENT, "getAgents")
	local agentPool = context.callS2S(SERVICE.AGENT, "getAgentPool")
	local cachedConfigs = context.callS2S(SERVICE.AGENT, "getConfigs")
    local updated = {}
    local configname = "activity_time"
    local oldValue = cachedConfigs[configname]
    local newValue = conf.host.new(activityConfig)
    if oldValue then
        markdirty(oldValue)
    end

    updated[configname] = newValue
    context.callS2S(SERVICE.AGENT, "updateConfigs", updated)
    
    for _, agent in pairs(agents) do
        context.sendS2S(agent, "updateConfigs", updated)
    end
    for _, agent in pairs(agentPool) do
        context.sendS2S(agent, "updateConfigs", updated)
    end

    local lotteryConf = activityConfig[activityTime.lottery]
    initLotteryRank(lotteryConf)
end

local function changeActivityTime(activityId, status, sTime, eTime, round, isApi)
	local config = activityConfig[activityId] or {}
	config.activityId = activityId
	config.status = status
	config.sTime = sTime
	config.eTime = eTime
	config.round = round
	activityConfig[activityId] = config
	if isApi then
		local msg = {activityId = activityId, status = (status == activityStatus.open), sTime = sTime, eTime = eTime}
		context.castS2C(nil, M_Activity.handleActivityTimeUpdate, msg)
		-- dump(msg)
		updateConfigs()
	end
	return SystemError.success
end

-- 状态注册
function command.notifySerivceStatus(serverName)
    isRegistered = true
end

local isRegistered = false
local function registerSerivce()
    if not isRegistered then
        context.sendS2S(SERVICE.AUTH, "notifySerivceStatus", SERVICE.ACTIVITY)
		isRegistered = true
    end
end

local function initConfig()
	local data = {
		method = "getBusinessActivityInfo",
		serverId = serverId,
	}
	local result = context.callS2S(SERVICE.RECORD, "callDataToCenter", data)
	if result then
		result = json.decode(result)
		if result and result.errorCode == 0 then
			local configs = result.data
			for _,config in pairs(configs) do
				local activityId = tonumber(config.activityId)
				local status = tonumber(config.status)
				local sTime = tonumber(config.sTime)
				local eTime = tonumber(config.eTime)
				local round = config.activityNum
				changeActivityTime(activityId, status, sTime, eTime, round)
			end
			updateConfigs()
		end
	else
		skynet.timeout(reTrySec * 100, function()
			initConfig()
		end)
	end
	registerSerivce()
end

function command.changeActivityTime(activityId, status, sTime, eTime, round, isApi)
	return changeActivityTime(activityId, status, sTime, eTime, round, isApi)
end

function command.getActiviyTime(activityId)
	if activityId then
		return activityConfig[activityId]
	else
		return activityConfig
	end
end

------------------------寻宝排行------------------------
local MAX_LOTTERY_RANK = 50
local GOLD_PER_ONE_SCORE = 1000
local LOTTERY_INTERVAL = 2

local lotteryActivityInfo
local lotteryRankInfo
local lotteryIsRunning

local checkLottery
local sendLotteryRankAward

local lotteryRankConfig = require("config.lottery_rank_config")

local function lotteryIsOpen()
	if not lotteryActivityInfo then
		return false
	end

	local now = os.time()
	if lotteryActivityInfo.status == activityStatus.open 
		and now >= lotteryActivityInfo.sTime 
		and now <= lotteryActivityInfo.eTime then
		return true
	end 
	return false
end

checkLottery = function()
	if lotteryIsRunning then
		command.syncRankInfo()

		if not lotteryIsOpen() then
			lotteryIsRunning = false
			sendLotteryRankAward()
			lotteryRankInfo = nil
		end
	else
		if lotteryIsOpen() then
			lotteryRankInfo = dbHelp.call("lottery.getRankInfo", lotteryActivityInfo.round)
			if not lotteryRankInfo then
				lotteryRankInfo = {totalScore = 0, roles = {}}
			end
			lotteryIsRunning = true
		end
	end

	skynet.timeout(LOTTERY_INTERVAL * 100, checkLottery)
end

initLotteryRank = function(info)
	lotteryActivityInfo = info
end

sendLotteryRankAward = function()
	for rank, role in ipairs(lotteryRankInfo.roles) do
		local conf = lotteryRankConfig[rank]
		if not conf then
			break
		end
		--发送邮件
		local goldNum = math.floor(conf.percent * lotteryRankInfo.totalScore)
		context.sendS2S(SERVICE.MAIL, "sendMail", role.roleId, {mailType = 1, pageType = 1, source = logConst.potGet, 
				attach = {{goodsId = roleConst.GOLD_ID, amount = goldNum}}, 
				title = language("LOTTERY_RANK_TILE"), 
				content = language("LOTTERY_RANK_CONTENT", rank)
			})
	end
end

function command.syncRankInfo()
	if lotteryIsOpen() then
		dbHelp.send("lottery.updateRankInfo", lotteryActivityInfo.round, lotteryRankInfo)
	end
end

function command.updateLotteryScore(roleId, nickname, joinTimes, score, addScore)
	if not lotteryIsOpen() then
		return
	end

	lotteryRankInfo.totalScore = lotteryRankInfo.totalScore + addScore

	if #lotteryRankInfo.roles == MAX_LOTTERY_RANK 
		and lotteryRankInfo.roles[MAX_LOTTERY_RANK].score >= score then
		return
	end

	local inRank
	for rank, role in ipairs(lotteryRankInfo.roles) do
		if role.roleId == roleId then
			inRank = true
			role.nickname = nickname
			role.joinTimes = joinTimes
			role.score = score
			role.updateTime = skynet.now()
			break
		end
	end

	if not inRank then
		lotteryRankInfo.roles[#lotteryRankInfo.roles + 1] 
			= {roleId = roleId, nickname = nickname, joinTimes = joinTimes, score = score, updateTime = skynet.now()}
	end

	table.sort(lotteryRankInfo.roles, function(r1, r2)
			if r1.score == r2.score then
				return r1.updateTime < r2.updateTime
			end
			return r1.score > r2.score
		end)

	if #lotteryRankInfo.roles > MAX_LOTTERY_RANK then
		lotteryRankInfo.roles[#lotteryRankInfo.roles] = nil
	end

	return lotteryRankInfo.totalScore
end

function command.getLotteryRank()
	if not lotteryIsOpen() then
		return
	end

	local result = {}
	for rank, role in ipairs(lotteryRankInfo.roles) do
		local conf = lotteryRankConfig[rank]
		local award = 0
		if conf then
			award = math.floor(conf.percent * lotteryRankInfo.totalScore)
		end
		
		result[rank] = {roleId = role.roleId, nickname = role.nickname, joinTimes = role.joinTimes, award = award}
	end
	return result
end

function command.getLotteryTotalScore()
	if not lotteryIsOpen() then
		return 0
	end
	return lotteryRankInfo.totalScore
end

---------------------------摇钱树----------------------------------


local moneyTreeConf = require("config.money_tree_config")
local isInitMoneyTree = false

local function getRandAward(randList)
	local totalWeight = 0
	for _,v in pairs(randList) do
		totalWeight = totalWeight + v.num
	end

	local randWeight = math.rand(1, totalWeight)

	local getInfo = {}
	local getWeight = 0
	for _, info in pairs(randList) do
		if randWeight > getWeight and randWeight <= (getWeight + info.num) then
			getInfo = info
			info.num = info.num - 1
			break
		end
		getWeight = getWeight + info.num
	end
	return getInfo
end

local function initMoneyTreeInfo(round)
	local infos = {}
	for _, conf in pairs(moneyTreeConf) do
		infos[#infos + 1] = {
			awardId = conf.id,
			num     = conf.num,
			round   = round
		}
	end
	dbHelp.call("moneyTree.initMoneyTreeInfo", infos)

	return infos
end

local function resetMoneyTreeInfo(round)
	local infos = {}
	local leftNum = 0
	for id, conf in pairs(moneyTreeConf) do
		infos[#infos + 1] = {
			awardId = conf.id,
			num     = conf.num,
			round   = round
		}

		leftNum = leftNum + conf.num
	end
	dbHelp.call("moneyTree.resetInfo", infos)

	return infos, leftNum
end

local function getMoneyTreeInfo(ret, round)
	local info = dbHelp.call("moneyTree.getInfo", round)
	if table.empty(info) then
		info = initMoneyTreeInfo(round)
	end
	local leftNum = 0
	for _,v in pairs(info) do
		leftNum = leftNum + v.num
	end

	if leftNum <= 0 then
		info, leftNum = resetMoneyTreeInfo(round)
	end
	ret.moneyTreeInfo = info
	ret.leftNum = leftNum
end

function command.getMoneyTreeInfo(round)
	local ret = {}
	queueEnter(getMoneyTreeInfo, ret, round)
	return ret
end

function command.moneyTreeLottery(round, num)
	local info = command.getMoneyTreeInfo(round)
	local moneyTreeInfo = info.moneyTreeInfo

	if info.leftNum < num then
		return MoneyTreeError.leftNumNotEnough
	end
	local awards = {}	   --要返回到前端的奖品id列
	for i=1, num do
		local randInfo = getRandAward(moneyTreeInfo)
		awards[#awards+1] = randInfo.awardId
		dbHelp.send("moneyTree.incrInfo", round, randInfo.awardId, -1)
	end

	return SystemError.success, awards
end

--------------------------许愿池--------------------------------

local wishWellConf = require("config.wish_well_config")


local function getWishWellRandAward(randList)
	local totalWeight = 0
	for _,v in pairs(randList) do
		totalWeight = totalWeight + v.num
	end

	local randWeight = math.rand(1, totalWeight)

	local getInfo = {}
	local getWeight = 0
	for _, info in pairs(randList) do
		if randWeight > getWeight and randWeight <= (getWeight + info.num) then
			getInfo = info
			info.num = info.num - 1
			break
		end
		getWeight = getWeight + info.num
	end
	return getInfo
end

local function initWishPoolInfo(round)
	local infos = {}
	for _, conf in pairs(wishWellConf) do
		infos[#infos + 1] = {
			awardId = conf.id,
			num     = conf.num,
			round   = round
		}
	end
	dbHelp.call("wishPool.initWishPoolInfo", infos)

	return infos
end

local function resetWishPoolInfo(round)
	local infos = {}
	local leftNum = 0
	for id, conf in pairs(wishWellConf) do
		infos[#infos + 1] = {
			awardId = conf.id,
			num     = conf.num,
			round   = round
		}

		leftNum = leftNum + conf.num
	end
	dbHelp.call("wishPool.resetInfo", infos)

	return infos, leftNum
end

local function getWishPoolInfo(ret, round)
	local info = dbHelp.call("wishPool.getInfo", round)
	if table.empty(info) then
		info = initWishPoolInfo(round)
	end
	local leftNum = 0
	for _,v in pairs(info) do
		leftNum = leftNum + v.num
	end

	if leftNum <= 0 then
		info, leftNum = resetWishPoolInfo(round)
	end

	ret.wishWellInfo = info
	ret.leftNum = leftNum
end

function command.getWishPoolInfo(round)
	local ret = {}
	queueEnter(getWishPoolInfo, ret, round)
	return ret
end

function command.wishPoolLottery(round, num)
	local info = command.getWishPoolInfo(round)
	local wishWellInfo = info.wishWellInfo

	if info.leftNum < num then
		return WishPoolError.overLeftNum
	end
	local awards = {}	   --要返回到前端的奖品id列
	for i=1, num do
		local randInfo = getWishWellRandAward(wishWellInfo)
		awards[#awards+1] = randInfo.awardId
		dbHelp.send("wishPool.incrInfo", round, randInfo.awardId, -1)
	end

	return SystemError.success, awards
end

-------------------------------------------------------

function activity.onStart()
	skynet.register(SERVICE.ACTIVITY)
	skynet.timeout(2 * 100, function()
		initConfig()
	end)
	skynet.timeout(LOTTERY_INTERVAL * 100, checkLottery)
	print("activity svc start")
end


activity.start()