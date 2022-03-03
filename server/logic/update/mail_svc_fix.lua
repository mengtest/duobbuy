local skynet = require("skynet")
local mailSvc = require("service_base")
local dbHelp = require("common.db_help")
local logger 	= require("log")
local hotfix = require("common.hotfix")
local mailConst = require("mail.mail_const")

local command = mailSvc.command

local announceMails =  hotfix.getupvalue(command.getMail, "announceMails")
local attachMails =  hotfix.getupvalue(command.getMail, "attachMails")

local function isMailExpire(mail)
	local now = skynet.time()
	if mail.mailType == mailConst.MailType.ATTACH then
		return now >= (mail.sendTime + mailConst.ATTACH_MAIL_EXPIRE)
	else
		return now >= (mail.sendTime + mailConst.ANNOUNCE_MAIL_EXPIRE)
	end
end

local function convertToProtoFormat(mail)
	if not mail then
		return
	end
	local retMail = { }
	table.merge(retMail, mail)
	retMail.endTime = mail.sendTime + mailConst.ANNOUNCE_MAIL_EXPIRE
	retMail.roleIds = nil
	retMail.source = nil
	-- local attach = { }
	-- if retMail.attach then
	-- 	for id, n in pairs(retMail.attach) do
	-- 		table.insert(attach, {goodsId = id, amount = n})
	-- 	end
	-- end
	-- retMail.attach = attach

	return retMail
end

function command.getMail(roleId, mailId)
	local mail = announceMails[mailId] or attachMails[mailId]
	if mail then
		if not mail.roleIds or mail.roleIds[roleId] then
			if not isMailExpire(mail) then
				return convertToProtoFormat(mail)
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
		return convertToProtoFormat(mail)
	end
end

print("ok-----")