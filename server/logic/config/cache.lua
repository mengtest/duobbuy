local conf = require("sharedata.corelib")
local pathprefix = "config."
local new = function(path)
    local data = require(pathprefix .. path)
    local cobj = conf.host.new(data)
    package.loaded[pathprefix .. path] = nil
    return cobj
end

function proxyConfig(origin)
	for k, v in pairs(origin) do
		local func = load(v)
		if func then
			origin[k] = func()
		end
	end
	return origin
end

local config 				= {}

config.fish					= new("fish")
config.fish_path			= new("fish_path")
config.fish_path_group		= new("fish_path_group")
config.fish_group			= new("fish_group")
config.fish_group_type		= new("fish_group_type")
config.fish_refresh			= new("fish_refresh")
config.fish_strikes_refresh	= new("fish_strikes_refresh")
config.gun_level			= new("gun_level")
config.pool					= new("pool")


config.global 				= new("global")
config.material 			= new("material")
config.diskRate 			= new("disk_rate")
config.gun 					= new("gun")
config.box 					= new("box")
config.fruitRate 			= new("fruit_rate")
config.shop 				= new("shop")
config.activity 			= new("activity_config")
config.recharge_disk_config = new("recharge_disk_config")
config.gun 					= new("gun")
config.gun_level_map		= new("gun_level_map")
config.novice_protection 	= new("novice_protection")
config.arena_config		 	= new("arena_config")
config.recharge_activity 	= new("recharge_activity")
config.daily_recharge 		= new("daily_recharge")
config.cumulate_recharge 	= new("cumulate_recharge")
config.arena_rank_award 	= new("arena_rank_award")
config.online_award		 	= new("online_award")
config.daily_task		 	= new("daily_task")
config.daily_task_team  	= new("daily_task_team")
config.power_unlock_config  = new("power_unlock_config")
config.recharge_disk_group 	= new("recharge_disk_group")
config.recharge_amount_config	= new("recharge_amount_config")
config.lucky_bag_rate 		= new("lucky_bag_rate")
config.login_award_config 	= new("login_award_config")
config.daily_sign 			= new("daily_sign")
config.cumulate_sign 		= new("cumulate_sign")
config.activity_time 		= new("activity_time")
config.return_award_config 	= new("return_award_config")
config.random_resource 		= new("random_resource")
config.sign_disk_rate       = new("sign_disk_rate")
config.wish_well_config     = new("wish_well_config")
config.treasure_config      = new("treasure_config")
config.lottery_rate    		= new("lottery_rate")
config.coupon_config     	= new("coupon_config")
config.coupon_award     	= new("coupon_award")
config.coupon_recharge     	= new("coupon_recharge")
config.bless_config 		= new("bless_config")
config.crazy_cycle 			= new("crazy_cycle")
config.continue_recharge    = new("continue_recharge")
config.everyday_recharge    = new("everyday_recharge")
config.invite_config 		= new("invite_config")
config.score_lottery_config = new("score_lottery_config")
config.score_lottery_total  = new("score_lottery_total")
config.money_tree_config  	= new("money_tree_config")
config.treasure_palace_config	= new("treasure_palace_config")
config.treasure_palace_box 	= new("treasure_palace_box")
config.relic_config 		= new("relic_level_config")
config.egg_cycle 			= new("egg_cycle")
config.gold_gun_config 		= new("gold_gun_level")
config.gold_gun_pool 		= new("gold_gun_pool")
config.qb_sign 				= new("qb_sign")
config.misc_online_config 	= new("misc_online_config")
config.level_config		 	= new("level_config")
config.gun_level_unlock		= new("gun_level_unlock")

config.robot_info 			= new("robot_info")


return config