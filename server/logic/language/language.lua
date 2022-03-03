local skynet = require("skynet")
local languageName = skynet.getenv("language")
languageName = languageName or "language_cn"
local CodeMsg = require("language."..languageName)

return function(key, ...)    
    if CodeMsg[key] == nil then
        local ResCode = require("language.language_cn")
        return string.format(ResCode[key], ...)        
    end
    return string.format(CodeMsg[key], ...)
end