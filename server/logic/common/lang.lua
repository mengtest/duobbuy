local skynet = require("skynet")
local language = skynet.getenv("language")

local LangMap = {
	language_cn		= "lang_zh_cn",
}

local lang = setmetatable({}, {
	__index = function(t, k)
		local l = require("config."..LangMap[language])
		return l[k]
	end
})

function lang.getStr(strKey, ...)
	return string.format(lang[strKey], ...)
end

return lang