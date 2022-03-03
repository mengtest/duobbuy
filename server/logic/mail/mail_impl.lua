local mailCtrl = require("mail.mail_ctrl")
local PageType = require("mail.mail_const").PageType
local MailState = require("mail.mail_const").MailState

local mailImpl = {}

function mailImpl.readMail(roleId, mailId)
	local ec, mail = mailCtrl.readMail(roleId, mailId)
	return ec, mail
end

function mailImpl.getAttachment(roleId, mailId)
	local ec, awards = mailCtrl.getAttachment(roleId, mailId)
	return ec, {mailIds = {mailId}, recvGoods = awards}
end

function mailImpl.getAllMailsStatus(roleId)
	local statuses = mailCtrl.getAllMailsStatus(roleId)
	local retMails = { system = {}, portal = {} }
	local function walkHandle(mail, id)
		if mail.pageType == PageType.SYSTEM then
			if mail.status == MailState.EMPTY then
				mail.status = MailState.READ
			end
			table.insert(retMails.system, mail)
		elseif mail.pageType == PageType.PORTAL then
			if mail.status == MailState.EMPTY then
				mail.status = MailState.READ
			end
			table.insert(retMails.portal, mail)
		end
	end

	table.walk(statuses, walkHandle)

	return SystemError.success, retMails
end

function mailImpl.recvAllAttach(roleId, pageType)
	local ec, ret, ret2 = mailCtrl.recvAllAttach(roleId, pageType)

	return ec, {mailIds = ret, recvGoods = ret2}
end

function mailImpl.delMail(roleId, mailId)
	local ec = mailCtrl.delMail(roleId, mailId)
	return ec, mailId
end

function mailImpl.delAllMail(roleId, pageType)
	local ec, ret = mailCtrl.delAllMail(roleId, pageType)

	return ec, {mailIds = ret}
end

return mailImpl