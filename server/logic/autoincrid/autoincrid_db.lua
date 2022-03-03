local json   = require("json")
-- local global = require("config.global")
local AutoIncrId = {}




function AutoIncrId.getMaxIncrId(db, key, offset)
	local ta = db[key]:find({},{_id = 1}):sort({ _id = -1}):limit(1)
    while ta:hasNext() do
        local value = ta:next()
        return value._id
    end
end

return AutoIncrId