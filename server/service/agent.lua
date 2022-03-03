local skynet = require("skynet")
local logger = require("log")
local context = require("common.context")
local configDb = require("config.config_db")
local dbHelp   = require("common.db_help")
local resOperate = nil
require("common.common_const")

local agent = require("service_base")
context.agent = agent
agent.isAgent = true
context.states.map = {}


local loginCallbacks = {}
local logoutCallbacks = {}
local tickCallbacks = {}

local registerLoginAndLogout
local initModules

dispatcher = require("common.event_dispatcher").new()

local command = agent.command

--[[
	初始化agent
	@param configs 缓存的配置键集合
]]
function command.init(configs)
	configDb.init(configs)
	initModules()
	registerLoginAndLogout()
end

--[[
	更新配置
	@param configs 缓存的配置键集合
]]
function command.updateConfigs(configs)
    configDb.update(configs)
end

local function onTick(roleId)
	local lastTickTime = skynet.time()
	for _, callback in ipairs(tickCallbacks) do
		local ok , msg = xpcall(function ()
			callback(roleId, lastTickTime)
		end, debug.traceback)
		if not ok then
	         logger.Errorf(string.format("roleOnTick: roleId = %s \n%s", roleId, msg))
	    end

	end
	-- 帧率补偿
	local onceProcessTime = skynet.time() - lastTickTime
	skynet.timeout(100, 
		function() 
			onTick(roleId) 
		end
	)
end

--[[
	初始化角色数据
	@param roleId 角色ID
	@param client 向客户端发送数据的服务地址
]]
function command.login(roleId, client, requestId, accountInfo)
	agent.roleId = roleId
	agent.client = client

	--调用登录回调函数
	for _, callback in ipairs(loginCallbacks) do
		callback(roleId, accountInfo)
	end
	onTick(roleId)

	context.responseC2S(client, requestId, M_Auth.login, SystemError.success, {roleId = roleId})
end

--[[
	agent退出（玩家登出）
]]
function command.logout()
	--调用登出回调函数
	for _, callback in ipairs(logoutCallbacks) do
		callback(agent.roleId)
	end
end

-- 非agent模块的转接接口
function command.doResOperate(operate, ...)
	if not resOperate then resOperate = require("common.res_operate") end

	local func = resOperate[operate]
	if func then
		return func(...)
	end
end

function command.dispatchEvent(event, ...)
	dispatcher:dispatchEvent(event, ...)
end

--[[
	供其他服务访问本服的模块函数
	@param roleId       agent对应的角色ID
    @param modCtrlPath  对应模块的ctrl文件位置，如：mail.mail_ctrl
    @param funcName     要访问的函数名
    @param ...          传给要访问函数的参数
]]
function command.doModLogic(roleId, modCtrlPath, funcName, ...)
	-- print("command.doModLogic(roleId, modCtrlPath, funcName, ...) roleId:"..roleId)
	local modCtrl = require(modCtrlPath)
	local func = modCtrl[funcName]
	return func(...)
end

local function addRegFunc(callbackFunc)
	if not callbackFunc then
		print ("注册了不存在的回调函数", debug.traceback())
	end
	return callbackFunc
end

--------------------------------------------
--[[
	注册登录和登出回调函数，注意注册顺序
]]
registerLoginAndLogout = function()
	loginCallbacks = {
		require("role.role_ctrl").onLoginBegin,	--确保第一个注册
		require("catch_fish.catch_fish_impl").onLogin,
		require("activity.activity_ctrl").onLogin,
		require("online_award.online_award_ctrl").onLogin,
		require("task.task_ctrl").onLogin,
		require("charge_disk.charge_disk_ctrl").onLogin,
		require("box.box_ctrl").onLogin,
		require("seven_day.seven_day_ctrl").onLogin,
		require("sign.sign_ctrl").onLogin,
		require("fund.fund_ctrl").onLogin,
		require("misc.misc_ctrl").onLogin,
		-- require("role.role_ctrl").onLoginOver,		--确保最后一个注册
	}

	--按照相反的顺序注册
	logoutCallbacks = {
		require("catch_fish.catch_fish_impl").onLogout,
		require("online_award.online_award_ctrl").onLogout,
		require("sign.sign_ctrl").onLogout,
		require("task.task_ctrl").onLogout,
		require("role.role_ctrl").onLogout,
		require("misc.misc_ctrl").onLogout,
	}

	-- 需要tick的模块
	tickCallbacks = {
		-- addRegFunc(require("sign.sign_ctrl").onTick),
	}
end

---------------------------------------------------------
local modules = {
	chat = "chat.chat_impl",
	role = "role.role_impl",
	lobby = "lobby.lobby_impl",
	catch_fish = "catch_fish.catch_fish_impl",
	disk = "disk.disk_impl",
	marquee = "marquee.marquee_impl",
	box = "box.box_impl",
	fruit = "fruit.fruit_impl",
	fund = "fund.fund_impl",
	misc = "misc.misc_impl",
	activity = "activity.activity_impl",
	shop = "shop.shop_impl",
	mobile = "mobile.mobile_impl",
	red_money = "red_money.red_money_impl",
	boss = "boss.boss_impl",
	rank = "rank.rank_impl",
	mail = "mail.mail_impl",
	online_award = "online_award.online_award_impl",
	task =	"task.task_impl",
	lucky_bag = "lucky_bag.lucky_bag_impl",
	pot = "pot.pot_impl",
	seven_day = "seven_day.seven_day_impl",
	sign = "sign.sign_impl",
	wish_pool = "wish_pool.wish_pool_impl",
	sign_disk = "sign_disk.sign_disk_impl",
	treasure_bowl = "treasure_bowl.treasure_bowl_impl",
	coupon = "coupon.coupon_impl",
	lottery = "lottery.lottery_impl",
	bless = "bless.bless_impl",
	crazy_box = "crazy_box.crazy_box_impl",
	invite = "invite.invite_impl",
	daily_charge = "daily_charge.daily_charge_impl",
	score_lottery = "score_lottery.score_lottery_impl",
	money_tree = "money_tree.money_tree_impl",
	treasure_palace = "treasure_palace.treasure_palace_impl",
	relic = "relic.relic_impl",
	egg = "egg.egg_impl",
	gold_gun = "gold_gun.gold_gun_impl",
	morrow_gift = "morrow_gift.morrow_gift_impl",
}
--初始化agent子模块
initModules = function()
    setmetatable(agent.modules, {
        __index = function(t, k)
            local mod = modules[k]
            if not mod then
                return nil
            end

            local v = require(mod)
            t[k] = v
            return v
        end
    })
end

--[[
	注册离线回调函数
	@param callback 回调函数
]]
function agent.registerLogoutCallback(callback)
	for _, item in pairs(logoutCallbacks) do
		if item == callback then
			return callback
		end
	end
	logoutCallbacks[#logoutCallbacks + 1] = callback
	return callback
end

--[[
	删除注册离线回调函数
	@param callback 回调函数
	@results 如果已经注册过该回调，返回false，否则返回true
]]
function agent.unregisterLogoutCallback(callback)
	for index, item in pairs(logoutCallbacks) do
		if item == callback then
			table.remove(logoutCallbacks, index)
			return true
		end
	end
	return false
end

function agent.onStart()
end
agent.start()
