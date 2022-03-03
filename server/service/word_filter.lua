local skynet = require("skynet")
local wordFilter = require("common.word_filter")
require("proto_map")

local command = require("command_base")


function command.isValid(input)
    return wordFilter.isValid(input)
end

function command.filter(input)
    return wordFilter.filter(input)
end

skynet.start(function()
    wordFilter.init()
    skynet.register(SERVICE.WORD_FILTER)
end)
