local skynet = require("skynet")

local mailSvc = require("service_base")
local dbHelp = require("common.db_help")
local mailConst = require("mail.mail_const")
local context = require("common.context")
local logger 	= require("log")

local command = mailSvc.command
--[[
	邮件数据结构
	mailId = xxx,
	mailType = xxx,		-- 类型：公告 or 附件
	title = "xxx",		-- 标题
	sendTime = xxx,		-- 发送时间
	subTitle = "xxx"	-- 副标题（可选）
	content = "xxx"		-- 内容
	roleIds = { 可选字段，没有该字段时表示全服邮件，存在该字段为发给指定角色的邮件。
		[id1] = true,
		[id2] = true,
		...
	}
	attach = { -- 附件物品（可选）
		{goodsId = xxx, amount = xxx, extraInfo = {...}},
		{goodsId = xxx, amount = xxx, extraInfo = {...}},
		...
	}	
]]
local attachMails = {}		-- 多人附件邮件
local announceMails = {}	-- 公告邮件

local function tableMerge(dest, src)
    for k, v in pairs(src) do
    	if not dest[k] then
    		 dest[k] = v
    	end
    end
end

local function convertToProtoFormat(mail, getSource)
	if not mail then
		return
	end
	local retMail = { }
	table.merge(retMail, mail)
	retMail.endTime = mail.sendTime + mailConst.ANNOUNCE_MAIL_EXPIRE
	retMail.roleIds = nil
	if getSource then
		--source
	else
		retMail.source = nil
	end
	-- local attach = { }
	-- if retMail.attach then
	-- 	for id, n in pairs(retMail.attach) do
	-- 		table.insert(attach, {goodsId = id, amount = n})
	-- 	end
	-- end
	-- retMail.attach = attach

	return retMail
end

local function isMailExpire(mail)
	local now = skynet.time()
	if mail.mailType == mailConst.MailType.ATTACH then
		return now >= (mail.sendTime + mailConst.ATTACH_MAIL_EXPIRE)
	else
		return now >= (mail.sendTime + mailConst.ANNOUNCE_MAIL_EXPIRE)
	end
end

local function isMultiMails(mailId)
	return announceMails[mailId] or attachMails[mailId]
end

-- 定时删除过期的多人邮件
local function delExpireMultiMails()
	local function checkAndDel(mails)
		local ids = {}
		for mailId, mail in pairs(mails) do
			if isMailExpire(mail) then
				table.insert(ids, mailId)
			end
		end

		for _, id in pairs(ids) do
			dbHelp.call("mail.delMail", id)
			mails[ids] = nil
		end
	end

	checkAndDel(attachMails)
	checkAndDel(announceMails)

	skynet.timeout(3600 * 100, function() delExpireMultiMails() end)
end

-- 过滤过期的、被标记为已删除的、不是发给自己的多人邮件
-- @param roleId 		角色ID
-- @mails mails 		要过滤的邮件列表
local function filterMultiMails(roleId, mails)
	local retMails = {}
	for mailId, m in pairs(mails) do
		if not m.roleIds or m.roleIds[roleId] then
			local state = dbHelp.call("mail.getMailState", roleId, mailId)
			if not isMailExpire(m) and state and state.status ~= mailConst.MailState.DELETED then
				retMails[mailId] = state
				tableMerge(retMails[mailId], convertToProtoFormat(m))
			end
		end
	end

	return retMails
end

-- 获取角色的所有单人邮件
local function getAllSingleMails(roleId)
	local singleMails = {}
	local mailsState = dbHelp.call("mail.getAllMailsState", roleId)
	for mailId, state in pairs(mailsState) do
		if not isMultiMails(mailId) then
			local mail = dbHelp.call("mail.getMail", mailId)
			if mail then
				if not isMailExpire(mail) then
					singleMails[mailId] = state
					local cvtMail = convertToProtoFormat(mail)
					tableMerge(singleMails[mailId], cvtMail)
				else
					-- 删除过期单人邮件
					dbHelp.call("mail.delMail", mailId)
					dbHelp.call("mail.delMailState", roleId, mailId)
				end
			else
				-- 邮件已被删除，需要清理无用标记
				dbHelp.call("mail.delMailState", roleId, mailId)
			end
		end
	end

	return singleMails
end

----------------------------------以下为mail服务的对外指令----------------------------------

--获取指定角色所有的邮件
function command.getMails(roleId)
	-- local ret = {}

	local filterAttachMails = filterMultiMails(roleId, attachMails)
	-- table.merge(ret, filterAttachMails)

	local filterAnnounceMails = filterMultiMails(roleId, announceMails)
	-- table.merge(ret, filterAnnounceMails)

	local singleMails = getAllSingleMails(roleId)
	table.merge(filterAttachMails, singleMails)

	return filterAttachMails, filterAnnounceMails
end

function command.getMail(roleId, mailId)
	local mail = announceMails[mailId] or attachMails[mailId]
	if mail then
		if not mail.roleIds or mail.roleIds[roleId] then
			if not isMailExpire(mail) then
				return convertToProtoFormat(mail, true)
			end
		end

		return
	else
		local mail = dbHelp.call("mail.getMail", mailId)
		if not mail then
			logger.Errorf("邮件失败，邮件不存在 roleId:%d mailId:%d", roleId, mailId)
			return
		else
			if mail.roleIds and not table.find(mail.roleIds, roleId) then
				return
			end	
		end
		return convertToProtoFormat(mail, true)
	end
end

-- 发送全服邮件
-- @param mailData	邮件内容
function command.sendGlobalMail(mailData)
	local mailId = dbHelp.call("mail.getIncMailId")
	local mail = {
		mailId = mailId,
		sendTime = skynet.time(),
	}
	table.merge(mail, mailData)
	dbHelp.call("mail.setMail", mail)

	if mail.mailType == mailConst.MailType.ATTACH then
		attachMails[mail.mailId] = mail
	else
		announceMails[mail.mailId] = mail
	end

	local cvtMail = convertToProtoFormat(mail)
	cvtMail.status = mailConst.MailState.UNREAD
	context.castS2C(nil, M_Mail.handleRecvMail, {mail = cvtMail})
end

--发送给指定角色的邮件
--@param roldIds	角色id列表
--@param mailData	邮件内容
function command.sendMailToRoles(roleIds, mailData)
	if #roleIds == 1 then
		command.sendMail(roleIds[1], mailData)
		return
	end

	local mailId = dbHelp.call("mail.getIncMailId")
	local mail = {
		mailId = mailId,
		sendTime = skynet.time(),
		roleIds = roleIds,
	}
	table.merge(mail, mailData)
	dbHelp.call("mail.setMail", mail)

	local ids = {}
	for _, id in ipairs(roleIds) do
		ids[id] = true
	end
	mail.roleIds = ids

	if mail.mailType == mailConst.MailType.ATTACH then
		attachMails[mail.mailId] = mail
	else
		announceMails[mail.mailId] = mail
	end

	local cvtMail = convertToProtoFormat(mail)
	cvtMail.status = mailConst.MailState.UNREAD
	context.sendMultiS2C(roleIds, M_Mail.handleRecvMail, {mail = cvtMail})
end

function command.sendMail(roleId, mailData)
	local mailId = dbHelp.call("mail.getIncMailId")
	local mail = {
		mailId = mailId,
		sendTime = skynet.time(),
		roleIds = {roleId},
	}
	table.merge(mail, mailData)

	dbHelp.call("mail.setMail", mail)
	dbHelp.call("mail.setMailState", roleId, mailId, "status", mailConst.MailState.UNREAD)

	local cvtMail = convertToProtoFormat(mail)
	cvtMail.status = mailConst.MailState.UNREAD

	context.sendS2C(roleId, M_Mail.handleRecvMail, {mail = cvtMail})
end

--删除邮件
--@param mailId 	邮件ID
--@param roleId 	角色ID（不为nil时，是删除单人邮件）
function command.delMail(roleId, mailId)
	local mail = attachMails[mailId] or announceMails[mailId]
	if not mail then
		mail = dbHelp.call("mail.getMail", mailId)
	end

	assert(mail, "不存在的邮件 roleId = "..roleId.." mailId = "..mailId)
	if mail.roleIds and table.nums(mail.roleIds) == 1 then
		dbHelp.call("mail.delMailState", roleId, mailId)
		dbHelp.call("mail.delMail", mailId)
	else
		dbHelp.call("mail.setMailState", roleId, mailId, "status", mailConst.MailState.DELETED)
	end
end

--领取附件
function command.getAttach(roleId, mailId)
	local mail = attachMails[mailId]
	if not mail then
		mail = dbHelp.call("mail.getMail", mailId)
	end
	assert(mail, "不存在的邮件 roleId = "..roleId.." mailId = "..mailId)
	dbHelp.call("mail.setMailState", roleId, mailId, "status", mailConst.MailState.EMPTY)
	dbHelp.call("mail.setMailState", roleId, mailId, "mailType", mailConst.MailType.ANNOUNCE)
end

local function init()
	local multiMails = dbHelp.call("mail.getMultiMails") or {}

	for _, m in pairs(multiMails) do
		local mail = {}
		for k, v in pairs(m) do
			if k == "roleIds" then
				local ids = {}
				for _, id in ipairs(v) do
					ids[id] = true
				end
				mail.roleIds = ids
			else
				mail[k] = v
			end
		end

		if m.mailType == mailConst.MailType.ATTACH then
			attachMails[m.mailId] = mail
		else
			announceMails[m.mailId] = mail
		end
	end

	delExpireMultiMails()
end

function mailSvc.onStart()
	init()

	skynet.register(SERVICE.MAIL)
	print("mail svc start")
end

mailSvc.start()