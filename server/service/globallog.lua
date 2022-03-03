require("skynet.manager")
local skynet = require("skynet")
local logger = require("log")

local logpath = skynet.getenv("logpath")
os.execute("mkdir -p " .. logpath)

local curLogIndex = 1
local curData = "_".. os.date("%Y%m%d") .. "_" .. curLogIndex

local divisionSize = 31457280

local dumpFile = io.open(logpath .. "server".. curData ..".log", "a")
local errorFile = io.open(logpath .. "error".. curData ..".log", "a")
local developerFile = io.open(logpath .. "developer".. curData ..".log", "a")

local function length_of_file(file)
    local len = file:seek("end")
    return len
end

function reCreateFile(file)
    file:close()
    curLogIndex = curLogIndex + 1
    curData = "_".. os.date("%Y%m%d") .. "_" .. curLogIndex

    if file == dumpFile then
        dumpFile = io.open(logpath .. "server".. curData ..".log", "a")
    elseif file == errorFile then
        errorFile = io.open(logpath .. "error".. curData ..".log", "a")
    elseif file == developerFile then
        developerFile = io.open(logpath .. "developer".. curData ..".log", "a")
    end
end

local dumplog = function(file, text)
    file:write(text)
    file:write("\n")
    file:flush()
    if length_of_file(file) > divisionSize then
        reCreateFile(file)
    end
end


local log_level_desc = {
    [0]     = "NOLOG",
    [10]    = "DEVELOPER",
    [20]    = "DEBUG",
    [30]    = "INFO",
    [40]    = "WARNING",
    [50]    = "ERROR",
    [60]    = "CRITICAL",
    [70]    = "FATAL",
}

--
-- log object
--
function log_format(self)
    if self.tags and next(self.tags) then
        return string.format("[%s %s] [%s]%s %s", self.timestamp,self.level,table.concat(self.tags, ","),self.src,self.msg)
    else
        return string.format("[%s %s]%s %s", self.timestamp,self.level,self.src,self.msg)
    end
end

--
-- end log object
--

local function log(name, modname, level, timestamp, msg, src, tags)
    if level == 10 then
        dumplog(developerFile, log_format {
            name = name,
            modname = modname,
            level = log_level_desc[level],
            timestamp = timestamp,
            msg = msg,
            src = src or '',
            tags = tags,
        })
    else
    	dumplog(dumpFile, log_format {
            name = name,
            modname = modname,
            level = log_level_desc[level],
            timestamp = timestamp,
            msg = msg,
            src = src or '',
            tags = tags,
    	})
    end
    if level == 50 then
        -- 再单独写一个ERROR.Log
        dumplog(errorFile, log_format {
        name = name,
        modname = modname,
        level = log_level_desc[level],
        timestamp = timestamp,
        msg = msg,
        src = src or '',
        tags = tags,
    })
    end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, ...)
		log(...)
	end)


	print("global log server start")
	skynet.register("LOG")
end)
