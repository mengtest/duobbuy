local skynet      = require("skynet")
local marquee     = require("service_base")
local marqueeCtrl = require("marquee.marquee_ctrl")
local marqueeConf = require("config.marquee")
local marqueeType = require("marquee.marquee_const").dayType
local context     = require("common.context")
local command 	  = marquee.command
local marqueesOn  = {}                       --在进行的运营跑马灯
local marqueeDistinct = 10000              --运营商与配置的跑马灯Id的分割点
local dayTotalSeconds = 86400             --一日秒数
local weekTotalSeconds = 7 * dayTotalSeconds        --一周秒数

--删除推送
local function delMsg(marqueeId)
	marqueesOn[marqueeId] = nil 
	context.castS2C(nil,M_Marquee.handleDelMsg,marqueeId)
end

--发送消息到前端
local function sendMsg(marqueeInfo)
	local marqueeId = marqueeInfo.id
	if marqueeId >= marqueeDistinct then
		if not marqueeCtrl.judgeMarqueeExist(marqueeId) then
			return
		end
	end
	marqueesOn[marqueeId] = marqueeInfo
	-- dump(marqueeInfo)
	context.castS2C(nil,M_Marquee.handleSendMsgBySentence,marqueeInfo)
end


--定时执行事件
local function timeout(timeLen, marqueeId, callback)
	skynet.timeout(timeLen * 100, function()
		if not marqueesOn[marqueeId] then
			return
		end
		callback(marqueeId)
	end)
end


--发送消息
local function sendMessage(marqueeInfo,endTime)
	sendMsg(marqueeInfo)
	local timeLen = endTime - os.time()
	timeout(timeLen, marqueeInfo.id, delMsg)
end


--判断是否发送
local function handleMarqueeOn(marqueeInfo,initFlag)
	-- dump(initFlag)
	-- print("handleMarqueeOn")
	local nowTime = os.time()
	local startTime = tonumber(marqueeInfo.startTime)
	local endTime	= tonumber(marqueeInfo.endTime)
	marqueeInfo.id        = tonumber(marqueeInfo.id)
	marqueeInfo.startTime = nil
	marqueeInfo.endTime   = nil
	marqueeInfo.leftTime  = 0
	-- print("nowTime:"..nowTime)
	-- print("startTime:"..startTime)
	-- print("endTime:"..endTime)
	if nowTime < startTime then
		skynet.timeout((startTime - nowTime) * 100, function() sendMessage(marqueeInfo,endTime) end)
	elseif nowTime >=startTime and nowTime < endTime then
		marqueesOn[marqueeInfo.id] = marqueeInfo
		if not initFlag then
			-- dump(marqueeInfo)
			context.castS2C(nil,M_Marquee.handleSendMsgBySentence,marqueeInfo)
		end
		local timeLen = endTime - nowTime
		timeout(timeLen, marqueeInfo.id, delMsg)
	end
end


--初始化正在进行的消息缓存
local function initCache()
    --生成运营消息缓存
	local marqueeInfos = marqueeCtrl.getMessage()
	if not table.empty(marqueeInfos) then
		for _,marqueeInfo in pairs(marqueeInfos) do
			handleMarqueeOn(marqueeInfo,true)
		end
	end
end

--获取正在进行的跑马灯
function command.getMessageOn()
	return marqueesOn
end


--增加或修改跑马灯消息
function command.setMessage(marqueeInfo)
	-- dump(marqueeInfo)
	if marqueesOn[marqueeInfo.id] then
		marqueeInfo.startTime = nil
		marqueeInfo.endTime   = nil
		marqueeInfo.leftTime  = 0
		marqueesOn[marqueeInfo.id] = marqueeInfo
		context.castS2C(nil,M_Marquee.handleAltMsg,marqueeInfo)
	else
		handleMarqueeOn(marqueeInfo)
	end
end


--删除跑马灯消息
function command.delMessage(marqueeId)
	if marqueesOn[marqueeId] then
		marqueesOn[marqueeId] = nil
		context.castS2C(nil,M_Marquee.handleDelMsg,marqueeId)
	end
end

-- 启动进程
function marquee.onStart()
	skynet.register(SERVICE.MARQUEE)
	skynet.timeout(1, function() initCache() end)
 	print("marquee server start")
end

marquee.start()