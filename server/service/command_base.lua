require("skynet.manager")
local skynet = require("skynet")
local json = require("json")
local logger = require("log")
local profile = require "profile"
require("debug")
require("errorcode")
require("functions")
require("monitor.monitor_ctrl")
require("common.event_code")
local ti = {}

local command = {}

function command.run(source, filename, ...)
	local output = {}
	local function print(...)
		local value = { ... }
		for k,v in ipairs(value) do
			value[k] = tostring(v)
		end
		table.insert(output, table.concat(value, "\t"))
	end

	local env = setmetatable({print = print, args = {...}}, {__index = _ENV})
	local func, err = load(source, filename, "bt", env)
	if not func then
		return {err}
	end

	local ok, err = xpcall(func, debug.traceback)
	if not ok then
		table.insert(output, err)
	end

	return output
end

local function profileCall(func, cmd, ...)
	profile.start()
	local ret1, ret2, ret3, ret4 = func(...)
	local time = profile.stop()
	local p = ti[cmd]
	if p == nil then
	p = { n = 0, ti = 0 }
	ti[cmd] = p
	end
	p.n = p.n + 1
	p.ti = p.ti + time
	return ret1, ret2, ret3, ret4
end

local function dispatch(session, address, cmd, ...)
	local func = command[cmd]
	local ret1, ret2, ret3, ret4
	if func then
		-- ret1, ret2, ret3, ret4 = profileCall(func, cmd, ...)
		ret1, ret2, ret3, ret4 = func(...)
	else
		logger.Errorf("[0x%x] cmd[%s] from address[0x%0x] is not found", skynet.self(), cmd, address)
	end
	if session > 0 then
		skynet.ret(skynet.pack(ret1, ret2, ret3, ret4))
	-- elseif ret1 ~= nil then
		-- logger.Errorf("cmd[%s] had return value, but caller[%s] not used call function", cmd, address)
	end
end

skynet.dispatch("lua", dispatch)

skynet.info_func(function()
  return {mem = collectgarbage("count"), profile = ti}
end)

return command
