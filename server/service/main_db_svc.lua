local skynet = require("skynet")
local profile = require "profile"
local json = require("json")
local logger = require("log")
local mongo = require("mongo")
require("functions")
--require("monitor.monitor_ctrl")

require("proto_map")


local db

local modules = {}
modules.auth 		= require("auth.auth_db")
modules.chat 		= require("chat.chat_db")
modules.role 		= require("role.role_db")
modules.autoincrid 	= require("autoincrid.autoincrid_db")
modules.disk 		= require("disk.disk_db")
modules.marquee 	= require("marquee.marquee_db")
modules.fruit 		= require("fruit.fruit_db")
modules.misc 		= require("misc.misc_db")
modules.charge 		= require("charge.charge_db")
modules.chargeDisk = require("charge_disk.charge_disk_db")
modules.catchFish = require("catch_fish.catch_fish_db")
modules.redMoney  	= require("red_money.red_money_db")
modules.share 		= require("share.share_db")
modules.activity 	= require("activity.activity_db")
modules.boss 		= require("boss.boss_db")
modules.rank 		= require("rank.rank_db")
modules.mail 		= require("mail.mail_db")
modules.task 		= require("task.task_db")
modules.onlineAward	= require("online_award.online_award_db")
modules.luckyBag 	= require("lucky_bag.lucky_bag_db")
modules.pot 		= require("pot.pot_db")
modules.box 		= require("box.box_db")
modules.sevenDay 	= require("seven_day.seven_day_db")
modules.sign 		= require("sign.sign_db")
modules.wishPool    = require("wish_pool.wish_pool_db")
modules.signDisk    = require("sign_disk.sign_disk_db")
modules.treasureBowl = require("treasure_bowl.treasure_bowl_db")
modules.coupon 		= require("coupon.coupon_db")
modules.lottery 		= require("lottery.lottery_db")
modules.bless 		= require("bless.bless_db")
modules.crazyBox 	= require("crazy_box.crazy_box_db")
modules.invite 		= require("invite.invite_db")
modules.dailyCharge = require("daily_charge.daily_charge_db")
modules.scoreLottery = require("score_lottery.score_lottery_db")
modules.moneyTree = require("money_tree.money_tree_db")
modules.treasurePalace = require("treasure_palace.treasure_palace_db")
modules.relic = require("relic.relic_db")
modules.egg = require("egg.egg_db")
modules.goldGun = require("gold_gun.gold_gun_db")
modules.morrowGift = require("morrow_gift.morrow_gift_db")

local ti = {}
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


-- local moduleNameFunCount = {}
local lua = {}
function lua.dispatch(session, address, cmd, ...)
	local moduleName, funcName = string.match(cmd, "(%w+)%.(%w+)")
	local module = modules[moduleName]
	local ret = nil
	if module then
		local func = module[funcName]
		if func then
			-- ret = profileCall(func, cmd, db, ...)
            ret = func(db, ...)
      --       if moduleNameFunCount[moduleName] == nil then
      --       	moduleNameFunCount[moduleName] = 0
      --       end
    		-- moduleNameFunCount[moduleName] = moduleNameFunCount[moduleName] + 1
    		-- print("db process ----- ", moduleName, moduleNameFunCount[moduleName], funcName)
		else
			logger.Errorf("db func[%s] is not found", funcName)
		end
	else
		logger.Errorf("db module[%s] is not found", moduleName)
	end
	if session > 0 then
		skynet.ret(skynet.pack(ret))
	elseif ret ~= nil then
		logger.Errorf("cmd[%s] had return value, but caller[%s] not used call function", cmd, address)
	end
end

skynet.dispatch("lua", lua.dispatch)

skynet.info_func(function()
  return ti
end)

local function connect()
    local dbhost = skynet.getenv("dbhost")
    local dbport = skynet.getenv("dbport")
    local dbname = skynet.getenv("dbname")
    local username = skynet.getenv("username")
    local password = skynet.getenv("password")
    local authmod = skynet.getenv("authmod")

    local conf = {host = dbhost, port = dbport, username = username, password = password, authmod = authmod}
    local dbclient = mongo.client(conf)
    db = dbclient:getDB(dbname)
end



skynet.start(function()
    connect()
end)