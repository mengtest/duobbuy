local skynet = require("skynet")
local context = require("common.context")
local dbHelp  = require("common.db_help")
local chatCtrl = require("chat.chat_ctrl")
local global = require("config.global")
local chatConst = require("chat.chat_const")

local chatSvc = require("service_base")

local command = chatSvc.command


local roles = {} 		-- 在线玩家聊天属性缓存
local linkCache = {}	-- 链接属性缓存
local forbidenRoles = {}

local function checkMsg(msg)
	-- local role = roles[msg.senderId]
	-- if not role then
	-- 	return SystemError.notLogin
	-- end

	-- msg.content = wordFilter.filter(msg.content)
	-- if not msg.content then
	-- 	return ChatError.contentIsInvalid
	-- end
	return SystemError.success
end

local function cacheLinkInfo(channelType, timeStamp, roleId, info)
	local cache = linkCache[channelType]
	local now = math.floor(skynet.time())
	while #cache > 0 do
		-- 清除过期的链接
		local info = cache[1]
		if info.timeStamp + chatConst.LINK_EXPIRE_TIME_LEN <= now then
			table.remove(cache, 1)
		else
			break
		end
	end

	local linkInfo = {
		timeStamp = timeStamp,
		roleId = roleId,
		info = {
			itemId = info.itemId,
			goodsId = info.goodsId,
			extractInfo = info.extractInfo,
			amount = info.amount,
		}
	}
	table.insert(cache, linkInfo)
end

-- 搜索链接信息
local function searchLinkInfo(cache, start, ended, roleId, timeStamp)
	if start > ended then
		return nil
	end

	local mid = math.floor((ended - start) / 2) + start
	local info = cache[mid]
	if info.timeStamp == timeStamp and info.roleId == roleId then
		return info
	elseif info.timeStamp > timeStamp then
		return searchLinkInfo(cache, start, mid - 1, roleId, timeStamp)
	elseif info.timeStamp < timeStamp then
		return searchLinkInfo(cache, mid + 1, ended, roleId, timeStamp)
	end
end

local function checkCanSpeak(chnType, msg)
	local senderId = msg.senderId
	local now = math.floor(skynet.time())

	local forbidExpire = forbidenRoles[senderId]
	if forbidExpire then
		if forbidExpire > now then
			return ChatError.forbidSpeak
		else
			dbHelp.call("chat.deleteForbidRole", senderId)
			forbidenRoles[senderId] = nil
		end
	end

	local cd = {
		[chatConst.ChannelType.WORLD] 		= global.CHAT_SPEAK_IN_WORLD_INTERVAL,
		[chatConst.ChannelType.UNION] 		= global.CHAT_SPEAK_IN_UNION_INTERVAL,
		[chatConst.ChannelType.PRIVATE] 	= global.CHAT_SPEAK_IN_PRIVATE_INTERVAL,
		[chatConst.ChannelType.NEARBY] 		= global.CHAT_SPEAK_IN_NEARBY_INTERVAL,
	}

	local sender = roles[senderId]
	if sender then
		local latestSpeak = sender.latestSpeak[chnType]
		if latestSpeak + cd[chnType] >= now then
			return ChatError.speakTooOfen
		end
	end

	return checkMsg(msg)
end

function command.printAllLinkInfo(chnType)
	dump(linkCache[chnType])
end

----------------------------------以下为服务对外指令----------------------------------

function command.onLogin(roleId, client, serverId)
	local latestSpeak = { }
	for _, t in pairs (chatConst.ChannelType) do
		latestSpeak[t] = 0
	end
	if roles[roleId] then
		roles[roleId].latestSpeak = latestSpeak
	else
		roles[roleId] = { latestSpeak = latestSpeak, forbidExpire = 0 }
	end
end

function command.onLogout(roleId, client)
	local role = roles[roleId]
	if role then
		roles[roleId] = nil
	end
end

--禁言
--@param roleId 	禁言角色ID
--@param timeLen	禁言时长（秒）
function command.forbidRoleSpeak(roleId,timeLen)
	local now = math.floor(skynet.time())
	local expire = now + timeLen
	forbidenRoles[roleId] = expire
	dbHelp.call("chat.setForbidRole", roleId, expire)
	context.sendS2C(roleId, M_Chat.onForbidSpeak, expire)

	return SystemError.success
end

function command.delForbidSpeak(roleId)
	roleId = tonumber(roleId)
	forbidenRoles[roleId] = nil
	dbHelp.call("chat.deleteForbidRole", roleId)
	return SystemError.success
end


------------------------------------------------
function command.speakToOne(msg, linkItem)
	local channelType = chatConst.ChannelType.PRIVATE
	local ec = checkCanSpeak(channelType, msg)
	if ec ~= SystemError.success then
		return ec
	end

	local reciever = roles[msg.recieverId]
	local sender = roles[msg.senderId]

	if not reciever then
		return ChatError.targetOffline
	end

	local now = math.floor(skynet.time())
	if linkItem then
		cacheLinkInfo(channelType, now, msg.senderId, linkItem)
	end

	sender.latestSpeak[channelType] = now

	msg.timeStamp = now
	context.sendMultiS2C({msg.recieverId, msg.senderId}, M_Chat.onSpeakToOne, msg)

	return SystemError.success
end

function command.speakToWorld(msg, linkItem)
	local channelType = chatConst.ChannelType.WORLD
	local ec = checkCanSpeak(channelType, msg)
	if ec ~= SystemError.success then
		return ec
	end

	local now = math.floor(skynet.time())
	if linkItem then
		cacheLinkInfo(channelType, now, msg.senderId, linkItem)
	end

	local sender = roles[msg.senderId]
	sender.latestSpeak[channelType] = now

	msg.timeStamp = now
	context.castS2C(nil, M_Chat.handleSpeakToWorld, msg)

	return SystemError.success
end

function command.speakToUnion(msg, linkItem)
	local channelType = chatConst.ChannelType.UNION
	local ec = checkCanSpeak(channelType, msg)
	if ec ~= SystemError.success then
		return ec
	end

	-- ###临时测试###
	local roleIds = {msg.senderId}
	if not roleIds then
		return SystemError.argument
	end

	local now = math.floor(skynet.time())
	if linkItem then
		cacheLinkInfo(channelType, now, msg.senderId, linkItem)
	end

	local sender = roles[msg.senderId]
	sender.latestSpeak[channelType] = now

	msg.timeStamp = now
	context.sendMultiS2C(roleIds, M_Chat.onSpeakToUnion, msg)

	return SystemError.success
end

function command.speakToNearby(msg, svcAddr, copyWorldId, linkItem)
	local channelType = chatConst.ChannelType.NEARBY
	local ec = checkCanSpeak(channelType, msg)
	if ec ~= SystemError.success then
		return ec
	end

	local now = math.floor(skynet.time())
	if linkItem then
		cacheLinkInfo(channelType, now, msg.senderId, linkItem)
	end

	local sender = roles[msg.senderId]
	if sender then
		sender.latestSpeak[channelType] = now
	end

	msg.timeStamp = now

	local roleIds = context.callS2S(svcAddr, "getAllRoles", copyWorldId)
	context.sendMultiS2C(roleIds, M_Chat.onSpeakToNearby, msg)

	return SystemError.success
end

function command.getLinkInfo(chnType, roleId, timeStamp)
	local cache = linkCache[chnType]
	local linkItem = searchLinkInfo(cache, 1, #cache, roleId, timeStamp)

	return linkItem
end

function chatSvc.onStart()
	skynet.register(SERVICE.CHAT)
	-- if wordFilter.init(filename) == false then
	-- 	logger.Errorf("initialize word filter failed, file path[%s]", filename)
	-- end


	skynet.timeout(1, function() context.sendS2S(SERVICE.AUTH, "watch", skynet.self()) end)
	forbidenRoles = dbHelp.call("chat.getForbidSpeakRoles")

	for _, t in pairs(chatConst.ChannelType) do
		linkCache[t] = {}
	end
end

chatSvc.start()