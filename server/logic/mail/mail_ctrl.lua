local dbHelp 	= require("common.db_help")
local context 	= require("common.context")
local mailConst = require("mail.mail_const")
local roleCtrl 	= require("role.role_ctrl")
local resOperate= require("common.res_operate")
local logger 	= require("log")
local logConst = require("game.log_const")

local mailCtrl = {}

local function getMailState(roleId, mailId)
	return dbHelp.call("mail.getMailState", roleId, mailId)
end

local function setMailState(roleId, mailId, name, state)
	dbHelp.call("mail.setMailState", roleId, mailId, name, state)
end


-- 判断邮件是否存在
local function isMailExist(roleId, mailId)
	if context.callS2S(SERVICE.MAIL, "getMail", roleId, mailId) then
		return true
	end
end

local function getMail(roleId, mailId)
	return context.callS2S(SERVICE.MAIL, "getMail", roleId, mailId)
end

local function getAttachMails(roleId)
	local mails = mailCtrl.getMails(roleId)
	local attachMails = {}
	for k, m in pairs(mails) do
		if m.mailType == mailConst.MailType.ATTACH then
			table.insert(attachMails, m)
		end
	end

	return attachMails
end

local function getAttach(roleId, mail)
	context.callS2S(SERVICE.MAIL, "getAttach", roleId, mail.mailId)

	local source = mail.source or logConst.mailGet
	resOperate.sendList(roleId, mail.attach, source)

	return SystemError.success, mail.attach
end

----------------------------------以下为mail_impl调用函数----------------------------------

--获取所有邮件
function mailCtrl.getMails(roleId)
	local attachMails, announceMails = context.callS2S(SERVICE.MAIL, "getMails", roleId)

	local tmpMails = table.values(attachMails)
	local function sortCallback(m1, m2)
		if m1.sendTime == m2.sendTime then
			return m1.mailId > m2.mailId
		else
			return m1.sendTime > m2.sendTime
		end
	end
	local attNum = #tmpMails
	if attNum > mailConst.MAX_MAIL_NUM then
		
		table.sort(tmpMails, sortCallback)

		for i = mailConst.MAX_MAIL_NUM + 1, attNum do
			local mail = tmpMails[i]
			if mail.roleIds and table.nums(mail.roleIds) == 1 then
				--单人邮件直接删除了
				context.callS2S(SERVICE.MAIL, "delMail", mail.mailId, roleId)
			else
				setMailState(roleId, mail.mailId, mailConst.MailState.DELETED)
			end
			attachMails[mail.mailId] = nil
		end
	end

	table.merge(attachMails, announceMails)

	local roleInfo = roleCtrl.getRoleInfo(roleId)
	for k, mail in pairs(attachMails) do
		if mail.sendTime < roleInfo.createTime then
			--发了邮件后才创建的角色，不能接收该附件邮件
			attachMails[k] = nil
		end
	end

	local result = table.values(attachMails)
	table.sort(result, sortCallback)

	return result
end

function mailCtrl.readMail(roleId, mailId)
	local mail = getMail(roleId, mailId)
	if mail then
		local state = getMailState(roleId, mailId)
		if not state or state.status == mailConst.MailState.UNREAD then
			setMailState(roleId, mailId, "status", mailConst.MailState.READ)
		end

		-- local attach = {}
		-- if mail.attach then
		-- 	for id, n in pairs(mail.attach) do
		-- 		table.insert(attach, {goodsId = id, amount = n})
		-- 	end
		-- end
		local retMail = {
			mailId = mail.mailId,
			content = mail.content,
			attach = mail.attach,
		}

		if state and (state.status == mailConst.MailState.DELETED or state.status == mailConst.MailState.EMPTY) then
			retMail.attach = nil
		end
		return SystemError.success, retMail
	else
		return MailError.invalidMail
	end
end

function mailCtrl.getAttachment(roleId, mailId)
	if not mailId then
		return MailError.invalidMail
	end

	local mail = getMail(roleId, mailId)
	if not mail then
		return MailError.invalidMail
	else
		if not mail.attach then
			return MailError.invalidAttach
		else
			local state = getMailState(roleId, mailId)
			if state and state.status == mailConst.MailState.DELETED then
				return MailError.invalidMail
			end

			if state and state.status == mailConst.MailState.EMPTY then
				return MailError.invalidAttach
			end

			return getAttach(roleId, mail)
		end
	end
end

function mailCtrl.getAllMailsStatus(roleId)
	local mails = mailCtrl.getMails(roleId)
	for _, mail in pairs(mails) do
		mail.content = nil
		mail.attach = nil
	end

	return mails
end

--[[
	领取所有附件邮件的附件
	@param  roleId 	角色ID
	@return ec
			recvMailIds 	成功领取的邮件ID列表
]]
function mailCtrl.recvAllAttach(roleId, pageType)
	local attachMails = getAttachMails(roleId)
	--按时间升序排列附件邮件
	local function sortCallBack(m1, m2)
		if m1.sendTime < m2.sendTime then
			return true
		end
	end
	table.sort(attachMails, sortCallBack)

	local recvMailIds = {} --成功领取的邮件ID
	local recvGoods = {}
	for _, mail in ipairs(attachMails) do
		if mail.pageType == pageType then
			local ec = getAttach(roleId, mail)
			if ec == SystemError.success then
				table.insert(recvMailIds, mail.mailId)
				table.insertto(recvGoods, mail.attach)
			else
				return ec, recvMailIds
			end
		end
	end

	local function mergeGoods(goods)
		local result = {}
		local keyInfo = {}
		for key,good in pairs(goods) do
			if good.goodsId then
				if keyInfo[good.goodsId] then
					local existKey = keyInfo[good.goodsId]
					result[existKey].amount = result[existKey].amount + good.amount
				else
					keyInfo[good.goodsId] = key
					result[#result+1] = good
				end
			end
		end
		return result
	end

	recvGoods = mergeGoods(recvGoods)

	return SystemError.success, recvMailIds, recvGoods
end

--[[
	删除邮件
]]
function mailCtrl.delMail(roleId, mailId)
	if not mailId then
		return MailError.invalidMail
	end

	local mail = getMail(roleId, mailId)
	if not mail then
		return MailError.invalidMail
	else
		context.callS2S(SERVICE.MAIL, "delMail", roleId, mailId)
		return SystemError.success
	end
end

--[[
	一键删除邮件
]]
function mailCtrl.delAllMail(roleId, pageType)
	local mails = mailCtrl.getMails(roleId)
	local delMailIds = {} --成功领取的邮件ID

	for _, mail in pairs(mails) do
		if mail.pageType == pageType and (mail.status == mailConst.MailState.READ or mail.status == mailConst.MailState.EMPTY) then
			local ec = mailCtrl.delMail(roleId, mail.mailId)
			if ec == SystemError.success then
				table.insert(delMailIds, mail.mailId)
			else
				return ec, delMailIds
			end
		end
	end

	return SystemError.success, delMailIds
end


return mailCtrl

