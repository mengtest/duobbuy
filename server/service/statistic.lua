local skynet  	= require("skynet")
local logger  	= require("log")
local json 		= require("json")
local md5    	= require("md5")
local mysql 	= require("mysql")
local context 	= require("common.context")
local dbHelp    = require("common.db_help")
local httpc 	= require("http.httpc")
local statistic    = require("service_base")
local logConst = require("game.log_const")
local language 	= require("language.language")

local command 	= statistic.command

local mysqlHost = skynet.getenv("mysqlHost")
local mysqlPort = skynet.getenv("mysqlPort")
local mysqlDatabase = skynet.getenv("mysqlDatabase")
local mysqlUser = skynet.getenv("mysqlUser")
local mysqlPassword = skynet.getenv("mysqlPassword")
local serverId = skynet.getenv("serverId")
local statisticIncrementSec = 3600


--------------------------------------

local rechargeActivityConf = require("config.recharge_activity")
local activityConst = require("activity.activity_const")
local dailyActivityId = activityConst.dailyActivityId
local roundActivityId = activityConst.roundActivityId
local dailyActivityConf = require("config.daily_recharge")
local roundActivityConf = require("config.cumulate_recharge")
local chargeCtrl = require("charge.charge_ctrl")

local OneDaySec = 86400 -- 	一天的秒数
local OneHourSec = 3600	--	一小时的秒数
local OneMinSec = 60 	--	一分钟的秒数
local OneWeekSec = 604800

local function getDayEndTime(sec)
	sec = sec or os.time()
	local timeDate = os.date("*t", sec)
	local dayEndTime = sec + OneDaySec - (timeDate.hour * OneHourSec + timeDate.min * OneMinSec + timeDate.sec)
	return dayEndTime, os.date("%Y%m%d", sec)
end

local function getDayHourTime(sec, hour)
	local dayEndTime = getDayEndTime(sec)
	local dayHourTime = dayEndTime - (24 - hour) * OneHourSec
	if dayHourTime < sec then
		dayHourTime = dayHourTime + OneDaySec
	end
	return dayHourTime
end

---------------------充值活动定时处理逻辑-------------------

local function getRechargeNextEndSec(sec)
	sec = sec or os.time()
	local beginTime = rechargeActivityConf[roundActivityId].beginTime
	local lastTime, spaceTime = rechargeActivityConf[roundActivityId].lastTime, rechargeActivityConf[roundActivityId].spaceTime
	if sec <= beginTime then
		return beginTime - sec + lastTime, 1
	end
	local passSec = sec - beginTime
	local round = math.ceil(passSec / (lastTime + spaceTime))
	local flagTime = passSec - (round - 1) * (lastTime + spaceTime)
	if flagTime <= lastTime then
		return beginTime + (round - 1) * (lastTime + spaceTime) + lastTime , round
	else
		return beginTime + (round) * (lastTime + spaceTime) + lastTime , round + 1
	end
end

local function dayRechargeActFunc(day, dayEndTime)
	logger.Debugf("dayRechargeActFunc start")
	skynet.timeout(OneDaySec * 100, function()
		local nextDayEndTime, nextDay = getDayEndTime(dayEndTime + 1)
		dayRechargeActFunc(nextDay, nextDayEndTime)
	end)
	command.dayHandle(day)
	logger.Debugf("dayRechargeActFunc end")
end

local function roundRechargeActFunc(round)
	logger.Debugf("roundRechargeActFunc start")
	local lastTime, spaceTime = rechargeActivityConf[roundActivityId].lastTime, rechargeActivityConf[roundActivityId].spaceTime
	skynet.timeout((lastTime + spaceTime) * 100, function()
		roundRechargeActFunc(round + 1)
	end)
	command.roundHandle(round)
	logger.Debugf("roundRechargeActFunc end")
end

local function rechargeHandleFunc()
	local curSec = os.time()
	local roundEndTime, round = getRechargeNextEndSec(sec)
	logger.Debugf("roundRechargeActFunc start left sec [%s]", roundEndTime - curSec)
	skynet.timeout((roundEndTime - curSec) * 100, function()
		roundRechargeActFunc(round)
	end)

	local dayEndTime, day = getDayEndTime(curSec)
	logger.Debugf("dayRechargeActFunc start left sec [%s]", dayEndTime - curSec)
	skynet.timeout((dayEndTime - curSec) * 100, function()
		dayRechargeActFunc(day, dayEndTime)
	end)
end

function command.dayHandle(day)
	local records = dbHelp.call("activity.getDailyHandle", day)
	local sendMsgRoles = {}
	for _,record in pairs(records) do
		local price = record.price or 0
		local roleId = record.roleId
		for index, conf in ipairs(dailyActivityConf) do
			if price >= conf.recharge then
				if not record[tostring(index)] then
					local award = conf.award
					dbHelp.call("activity.recordDailyAward", roleId, day, index)
					chargeCtrl.sendGoods(roleId, {{goodsId = award.goodsId, amount = award.amount}}, logConst.dailyRechargeGet)
					if not sendMsgRoles[roleId] then
						context.sendS2C(roleId, M_Activity.handleDaySendAward)
						sendMsgRoles[roleId] = true
					end
				end
			else
				break
			end
		end
	end
end

-------------------------------活动结束处理------------------------------------------------

function command.roundHandle(round)
	local records = dbHelp.call("activity.getRoundHandle", round)
	local sendMsgRoles = {}
	for _,record in pairs(records) do
		local price = record.price or 0
		local roleId = record.roleId
		for index, conf in ipairs(roundActivityConf) do
			if price >= conf.recharge then
				if not record[tostring(index)] then
					local award = conf.award
					dbHelp.call("activity.recordRoundAward", roleId, round, index)
					chargeCtrl.sendGoods(roleId, {{goodsId = award.goodsId, amount = award.amount}}, logConst.roundRechargeGet)
					if not sendMsgRoles[roleId] then
						context.sendS2C(roleId, M_Activity.handleRoundSendAward)
						sendMsgRoles[roleId] = true
					end
				end
			else
				break
			end
		end
	end
end

---------------------------------------------

-------------------------------竞技场排行榜-------------------------------

local arenaRankAwardConf = require("config.arena_rank_award")
local rankConst = require("rank.rank_const")
local RankType  = rankConst.rankType
local awardType = rankConst.awardType
local sendStatus = rankConst.sendStatus

local function arenaDayAwardActFunc()
	logger.Debugf("arenaDayAwardActFunc start" .. os.date("%Y%m%d %H%M%S"))
	skynet.timeout(OneDaySec*100, function()
		arenaDayAwardActFunc()
	end)

	local conf = arenaRankAwardConf[RankType.dayArena]
	local lastKey = os.date("%Y%m%d", os.time() - OneDaySec)
	local lastPosInfo = dbHelp.call("rank.getTopRank", RankType.dayArena, lastKey, #conf)
	if lastPosInfo then
		local pushList = {}
		for _,info in pairs(lastPosInfo) do
			local pos = info.pos
			local roleId = info.roleId
			local awardInfo = dbHelp.call("rank.getRankConfig", RankType.dayArena, pos)
			if awardInfo then
				if awardInfo.awardType == awardType.game then
					context.sendS2S(SERVICE.MAIL, "sendMail", roleId, {mailType = 1, pageType = 1, source = logConst.arenaDayRankGet, attach = {{goodsId = awardInfo.goodsId, amount = awardInfo.amount}}, title = language("竞技场排行奖励"), content = language("竞技场每日结算", pos, awardInfo.awardName)})
					dbHelp.send("rank.recordGoodsAward", roleId, RankType.dayArena, awardInfo.awardName, pos, sendStatus.done, awardInfo.goodsId)
				elseif awardInfo.awardType == awardType.real then
					context.sendS2S(SERVICE.MAIL, "sendMail", roleId, {mailType = 2, pageType = 1, source = logConst.arenaDayRankGet, title = language("竞技场排行奖励"), content = language("竞技场每日结算", pos, awardInfo.awardName)})
					dbHelp.send("rank.recordGoodsAward", roleId, RankType.dayArena, awardInfo.awardName, pos, sendStatus.inHandle, awardInfo.goodsId)
				end
				pushList[#pushList+1] = roleId
			end
		end

		if #pushList > 0 then
			command.sendArenaPush(pushList)
		end
	end

	logger.Debugf("arenaDayAwardActFunc end" .. os.date("%Y%m%d %H%M%S"))
end

local function arenaWeekAwardActFunc()
	logger.Debugf("arenaWeekAwardActFunc start" .. os.date("%Y%m%d %H%M%S"))
	skynet.timeout(OneWeekSec*100, function()
		arenaWeekAwardActFunc()
	end)

	local conf = arenaRankAwardConf[RankType.weekArena]
	local lastKey = os.date("%Y%W", os.time() - OneWeekSec)
	local lastPosInfo = dbHelp.call("rank.getTopRank", RankType.weekArena, lastKey, #conf)
	if lastPosInfo then
		local pushList = {}
		for _,info in pairs(lastPosInfo) do
			local pos = info.pos
			local roleId = info.roleId
			local awardInfo = dbHelp.call("rank.getRankConfig", RankType.weekArena, pos)
			if awardInfo then
				if awardInfo.awardType == awardType.game then
					context.sendS2S(SERVICE.MAIL, "sendMail", roleId, {mailType = 1, pageType = 1, source = logConst.arenaWeekRankGet, attach = {{goodsId = awardInfo.goodsId, amount = awardInfo.amount}}, title = language("竞技场排行奖励"), content = language("竞技场每周结算", pos, awardInfo.awardName)})
					dbHelp.send("rank.recordGoodsAward", roleId, RankType.weekArena, awardInfo.awardName, pos, sendStatus.done, awardInfo.goodsId)
				elseif awardInfo.awardType == awardType.real then
					context.sendS2S(SERVICE.MAIL, "sendMail", roleId, {mailType = 2, pageType = 1, source = logConst.arenaWeekRankGet, title = language("竞技场排行奖励"), content = language("竞技场每周结算", pos, awardInfo.awardName)})
					dbHelp.send("rank.recordGoodsAward", roleId, RankType.weekArena, awardInfo.awardName, pos, sendStatus.inHandle, awardInfo.goodsId)
				end
			end
			pushList[#pushList+1] = roleId
		end

		if #pushList > 0 then
			command.sendArenaPush(pushList)
		end
	end
	logger.Debugf("arenaWeekAwardActFunc end" .. os.date("%Y%m%d %H%M%S"))
end


local function arenaRankHandleFunc()
	local curSec = os.time()
	local dayEndTime = getDayEndTime(curSec)
	logger.Debugf("arenaRankHandleFunc arenaDayAwardActFunc start left sec [%s]", dayEndTime - curSec)
	skynet.timeout((dayEndTime - curSec) * 100, function()
		arenaDayAwardActFunc()
	end)

	local wIndex = os.date("%w", curSec)
	local nextWeekSec = dayEndTime - curSec + ((7- wIndex) % 7) * OneDaySec
	logger.Debugf("arenaRankHandleFunc arenaWeekAwardActFunc start left sec [%s]", nextWeekSec)
	skynet.timeout(nextWeekSec * 100, function()
		arenaWeekAwardActFunc()
	end)
end

function command.sendArenaPush(roleIds)
	local data = {
		method = "sendArenaPush",
		roleIds = json.encode(roleIds),
	}
	context.sendS2S(SERVICE.RECORD, "sendDataToCenter", data)
end

------------------------------------------------------------------


--------------------------------------月卡定时器逻辑处理(30天内每日凌晨邮件发放)-------------------------------
local chargeConst = require("charge.charge_const")
local roleConst  = require("role.role_const")

local function monthCardAwardActFunc()
	logger.Debugf("monthCardAwardActFunc start" .. os.date("%Y%m%d %H%M%S"))
	skynet.timeout(OneDaySec*100, function()
		monthCardAwardActFunc()
	end)
	local monthCardInfo = dbHelp.call('charge.getAllMonthCardDays')
	if not table.empty(monthCardInfo) then
		local mailData = {mailType = 1, pageType = 1, source = logConst.chargeGet, attach = {{goodsId = roleConst.GOLD_ID, amount = chargeConst.monthCardGoldGetPerDay}}, title = language("月卡奖励")}
		for roleId, leftDays in pairs(monthCardInfo) do
			if leftDays >=1 then
				local finalLeftDays = leftDays - 1
				mailData.content = language("月卡奖励内容", finalLeftDays)
				dbHelp.send('charge.incryMonthCardDays', roleId, -1)
				context.callS2S(SERVICE.MAIL, "sendMail", roleId, mailData)
			end
		end
	end
end


local function monthCardHandleFunc()
	local curSec = os.time()
	local dayEndTime = getDayEndTime(curSec)
	logger.Debugf("monthCardHandleFunc mothCardAwardActFunc start left sec [%s]", dayEndTime - curSec)
	skynet.timeout((dayEndTime - curSec) * 100, function()
		monthCardAwardActFunc()
	end)
end

------------------------------------------------------------------


--------------------------------------月卡定时器逻辑处理(30天内每日凌晨邮件发放)-------------------------------
local chargeConst = require("charge.charge_const")
local roleConst  = require("role.role_const")
local GiftConfig = require("config.gift")

local function giftHandleActFunc()
	logger.Debugf("giftHandleActFunc start" .. os.date("%Y%m%d %H%M%S"))
	skynet.timeout(OneDaySec*100, function()
	-- skynet.timeout(300*100, function()
		giftHandleActFunc()
	end)
	-- 记录玩家，发送短信
	local playerList = {}
	local allGiftInfoList = dbHelp.call('charge.getAllGiftInfoList')
	for roleId,giftInfoIndex in pairs(allGiftInfoList or {}) do
		for giftId,day in pairs(giftInfoIndex) do
			local GiftVO = GiftConfig[giftId]
			if day >= 1 and GiftVO then
				-- 扣除天数
				dbHelp.send('charge.incryGiftDays', roleId, giftId, -1)

				local mailData = {
					mailType = 1, 
					pageType = 1, 
					source = logConst.chargeGiftGet, 
					attach = {}
				}
				mailData.title = GiftVO.title
				mailData.content = string.format(GiftVO.content, day - 1)
				if (day - 1) <= 3 then
					mailData.content = string.format(GiftVO.last_content, day - 1)
				end
				if day == 1 then
					mailData.content = string.format(GiftVO.end_content, day - 1)
				end
				for _,goodsInfo in pairs(GiftVO.goods) do
					table.insert(mailData.attach, {goodsId = goodsInfo.goodsId, amount = goodsInfo.amount, gunId = goodsInfo.gunId, time = goodsInfo.time})
					context.callS2S(SERVICE.MAIL, "sendMail", roleId, mailData)
				end
				-- 记录玩家
				table.insert(playerList, {roleId = roleId, giftId = giftId})
			end
		end
	end
	-- if not table.empty(playerList) then
	-- 	context.sendS2S(SERVICE.RECORD, "sendDataToCenter", data)
	-- end
end

local function giftHandleFunc()
	local curSec = os.time()
	local dayHourTime = getDayHourTime(curSec, 21)
	logger.Debugf("giftHandleFunc giftHandleActFunc start left sec [%s]", dayHourTime - curSec)
	skynet.timeout((dayHourTime - curSec) * 100, function()
	-- skynet.timeout((10) * 100, function()
		giftHandleActFunc()
	end)
end

---------------------------------------------------------------------------------------------------------------------
local LuckyBagMsgConfig = require("config.lucky_bag_msg")
local LuckyBagConfig = require("config.lucky_bag_config")
local RobotInfoConfig = require("config.robot_info")
local RobotLuckyRecordList = {}
local function luckyBagRecordHandleFunc()
	local hour = tonumber(os.date("%H"))
	local LuckyBagMsgVO 
	for _,otherLuckyBagMsgVO in pairs(LuckyBagMsgConfig) do
		if otherLuckyBagMsgVO.start_time <= hour and hour <= otherLuckyBagMsgVO.end_time then
			LuckyBagMsgVO = otherLuckyBagMsgVO
		end
	end
	if not LuckyBagMsgVO then
		skynet.timeout(60 * 100, luckyBagRecordHandleFunc)
		return
	end

	-- 随机间隔
	local interval = math.rand(LuckyBagMsgVO.interval[1], LuckyBagMsgVO.interval[2])
	skynet.timeout(interval * 100, luckyBagRecordHandleFunc)

	-- 随机一个机器人
	local nickname
	local randomRobotIndex = math.floor(math.rand(table.nums(RobotInfoConfig)))
	for _,RobotInfoVO in pairs(RobotInfoConfig) do
		randomRobotIndex = randomRobotIndex - 1
		if randomRobotIndex <= 0 then
			nickname = RobotInfoVO.key
			break
		end
	end
	if not nickname then
		return
	end
	
	-- 随机一个物品
	local totalNum = 0
	for _,goodsInfo in pairs(LuckyBagMsgVO.random_goods) do
		totalNum = totalNum + goodsInfo[2]
	end
	local goodsIndex
	local randomNum = math.rand(0, totalNum)
	for _,goodsInfo in pairs(LuckyBagMsgVO.random_goods) do
		randomNum = randomNum - goodsInfo[2]
		if randomNum <= 0 then
			goodsIndex = goodsInfo[1]
			break
		end
	end	
	if not goodsIndex then return end
	local LuckyBagVO = LuckyBagConfig[goodsIndex]
	if not LuckyBagVO then return end

	local goodsType = 2
	if LuckyBagVO.bag_type == 1 then
		goodsType = 1
	end
	table.insert(RobotLuckyRecordList, {type = goodsType, nickname = nickname, goodsName = LuckyBagVO.content, time = os.time()})
	if #RobotLuckyRecordList > 10 then
		table.remove(RobotLuckyRecordList, 1)
	end
end

function command.getRobotLuckyRecordList()
	return RobotLuckyRecordList or {}
end
---------------------------------------------------------------------------------------------------------------------


local function statisticIncrement(timeoutSec)
	local logAdd, logReduce = {}, {}
	local flag = false
	local func = function(attrName, changeVal)
		if changeVal > 0 then
			if logAdd[attrName] then
				logAdd[attrName] = logAdd[attrName] + changeVal
			else
				logAdd[attrName] = changeVal
			end
		else
			if logReduce[attrName] then
				logReduce[attrName] = logReduce[attrName] + changeVal
			else
				logReduce[attrName] = changeVal
			end
		end
		if flag then
			return
		end
		flag = true
		skynet.timeout(timeoutSec * 100, function()
			flag = false
			local goldAdd, goldReduce = logAdd["gold"] or 0, logReduce["gold"] or 0
			local treasureAdd, treasureReduce = logAdd["treasure"] or 0, logReduce["treasure"] or 0
			local cTime = os.date("'%Y-%m-%d %H:%M:%S'")
			local cDate = os.date("'%Y-%m-%d'")
			local sqlArray = {goldAdd, goldReduce, treasureAdd, treasureReduce, cTime, cDate, serverId}
			local sqlValues = table.concat(sqlArray, ",")
			local query = "insert into `tbl_statistic_info` (`goldAdd`, `goldReduce`, `treasureAdd`, `treasureReduce`, `cTime`, `cDate`, `serverId`) values (".. sqlValues ..");"
			command.mysqlQuery(query)
			logAdd, logReduce = {}, {}
		end)
	end
	return func
end
local incrementLog = statisticIncrement(statisticIncrementSec)

------------

local function mysqlQuery(query)
	local db  = mysql.connect({
		host = mysqlHost,
		port = mysqlPort,
		database = mysqlDatabase,
		user = mysqlUser,
		password = mysqlPassword,
	})
	db:query(query)
end


-- 记录资源增量
function command.statisticIncrement(attrName, changeVal)
	incrementLog(attrName, changeVal)
end

-- mysql记录
function command.mysqlQuery(query)
	mysqlQuery(query)
end

-----

-- 记录玩家夺宝信息
local AllRecordInfoList = {}
local AllLuckyRecordInfoList = {}
function command.recordFundResult(prizeId, round, winner, roleIdList, goodsName)
	for _,strRoleId in pairs(roleIdList) do
		local roleId = tonumber(strRoleId)
		AllRecordInfoList[roleId] = AllRecordInfoList[roleId] or {}
		AllRecordInfoList[roleId][prizeId] = AllRecordInfoList[roleId][prizeId] or {}
		AllRecordInfoList[roleId][prizeId][round] = goodsName


		if roleId == winner then 
			AllLuckyRecordInfoList[roleId] = AllLuckyRecordInfoList[roleId] or {}
			AllLuckyRecordInfoList[roleId][prizeId] = AllLuckyRecordInfoList[roleId][prizeId] or {}
			AllLuckyRecordInfoList[roleId][prizeId][round] = goodsName
		end

		-- 发送通知
		local fundRecordInfo = command.getFundInfo(roleId)
		-- dump(fundRecordInfo)
		context.sendS2C(roleId, M_Fund.onSyncFundRecord, fundRecordInfo)
	end
end

function command.getFundInfo(roleId)
	local data = {}
	data.recordInfoList = {}
	data.luckyRecordInfoList = {}

	local recordInfoList = AllRecordInfoList[roleId] or {}
	for prizeId,prizeInfo in pairs(recordInfoList) do
		for round,goodsName in pairs(prizeInfo) do
			table.insert(data.recordInfoList, {prizeId = prizeId, round = round, goodsName = goodsName})
		end
	end

	local luckyRecordInfoList = AllLuckyRecordInfoList[roleId] or {}
	for prizeId,prizeInfo in pairs(luckyRecordInfoList) do
		for round,goodsName in pairs(prizeInfo) do
			table.insert(data.luckyRecordInfoList, {prizeId = prizeId, round = round, goodsName = goodsName})
		end
	end
	return data
end

function command.readFundRecord(roleId, type)
	-- print("command.readFundRecord(roleId, type) roleId:"..roleId.." type:"..type)
	if type == 1 then
		AllRecordInfoList[roleId] = nil
	else
		AllLuckyRecordInfoList[roleId] = nil
	end
	-- dump(AllRecordInfoList[roleId])
	-- dump(AllLuckyRecordInfoList[roleId])
end

-- 启动进程
function statistic.onStart()
	skynet.register(SERVICE.STATISTIC)
	-- rechargeHandleFunc()
	arenaRankHandleFunc()
	monthCardHandleFunc()        --月卡每日凌晨發放
	giftHandleFunc()
	luckyBagRecordHandleFunc()
	print("statistic server start")
end

statistic.start()