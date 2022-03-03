local dbHelp = require("common.db_help")
local mailConst = require("mail.mail_const")
local context = require("common.context")
local mailDb = {}
function mailDb.getIncMailId(db)
	return context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "Mails")
end

--读取所有多人邮件
function mailDb.getMultiMails(db)
	local mails = db.Mails:find({delete = { ["$exists"] = false }})

	local multiMails = {}
	while mails:hasNext() do
		local mail = mails:next()
		if not mail.roleIds or #mail.roleIds ~= 1 then
			-- 没roleIds或者roleIds中id数量不为1，表示为多人邮件
			mail.mailId = mail._id
			mail._id = nil
			table.insert(multiMails, mail)
			-- if mail.mailType == mailConst.MailType.ATTACH then
			-- 	local attach = {}
			-- 	for id, amount in pairs(mail.attach) do
			-- 		attach[tonumber(id)] = amount
			-- 	end
			-- 	mail.attach = attach
			-- end
		end
	end

	return multiMails
end

--记录新的邮件
function mailDb.setMail(db, data)
	local doc = {
		_id 		= data.mailId,
		sendTime 	= data.sendTime,
		mailType	= data.mailType,
		title 		= data.title,
		subTitle 	= data.subTitle,
		content 	= data.content,
		attach 		= data.attach,
		roleIds 	= data.roleIds,
		source 		= data.source,
		pageType  	= data.pageType,
	}
	db.Mails:insert(doc)
end

function mailDb.getMail(db, mailId)
	local mail = db.Mails:findOne({ _id = mailId, delete = { ["$exists"] = false }})
	if mail then
		mail.mailId = mail._id
		mail._id = nil
		-- if mail.mailType == mailConst.MailType.ATTACH then
		-- 	local attach = {}
		-- 	for id, amount in pairs(mail.attach) do
		-- 		attach[tonumber(id)] = amount
		-- 	end
		-- 	mail.attach = attach
		-- end
	end
	return mail
end

function mailDb.delMail(db, mailId)
	db.Mails:update(
		{_id = mailId},
		{["$set"] = { delete = true } }
	)
end

function mailDb.getMailState(db, roleId, mailId)
	local key = roleId .. "|" .. mailId
	local status = db.MailState:findOne({_id = key, delete = { ["$exists"] = false }})
	if status then
		status._id = nil
		status.roleId = nil
		return status
	else
	 	return {status = mailConst.MailState.UNREAD}
	end
end

function mailDb.setMailState(db, roleId, mailId, name, val)
	local key = roleId .. "|" .. mailId
	db.MailState:update(
        { _id = key },
        { ["$set"] = { [name] = val, ["roleId"] = roleId} },
        {upsert = true}
    )
end

function mailDb.getAllMailsState(db, roleId)
	local states = db.MailState:find({["roleId"] = roleId, delete = { ["$exists"] = false }})

	local ret = {}
	while states:hasNext() do
		local st = states:next()
		local key = st._id
		local keyList = string.split(key, "|")
		local mailId = tonumber(keyList[2])
		st._id = nil
		st.roleId = nil
		ret[mailId] = st
	end

	return ret
end

function mailDb.delMailState(db, roleId, mailId)
	local key = roleId .. "|" .. mailId
	db.MailState:update(
		{_id = key}, 
		{["$set"] = { delete = true } }
	)
end

return mailDb