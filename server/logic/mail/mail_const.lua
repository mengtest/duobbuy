local MailConst = {}

MailConst.ANNOUNCE_MAIL_EXPIRE 	= 30 * 24 * 3600 	-- 公告邮件过期时间（秒）
MailConst.ATTACH_MAIL_EXPIRE 	= 30 * 24 * 3600	-- 附件邮件过期时间（秒）
MailConst.MAX_MAIL_NUM = 50	--邮件数量上限

MailConst.MailType = {
	ATTACH = 1,		-- 附件
	ANNOUNCE = 2,	-- 公告
}

MailConst.MailState = {
	UNREAD = 1,		-- 未读
	READ = 2,		-- 已读
	DELETED = 3,	-- 删除
	EMPTY  = 4, 	-- 已领取
}

MailConst.PageType = {
	SYSTEM = 1, 	--系统
	PORTAL = 2,		--奖品
}

return MailConst