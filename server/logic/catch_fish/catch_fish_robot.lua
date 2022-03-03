local table = table
local math = math
local skynet = require("skynet")
local logger = require("log")
local context = require("common.context")

local RobotPool = {}

-- 初始化机器人
function CathFishRobotMgr.initRobot()
    local robotId = 0
    for _,RobotInfoVO in pairs(RobotInfoConfig) do
        local RobotCathFishVO = RobotCathFishConfig[(RobotInfoVO.cath_fish or 0)]
        if RobotCathFishVO then
            robotId = robotId + 1

            local robotInfo = {}
            robotInfo.roleId            = robotId
            robotInfo.avatar            = RobotInfoVO.icon
            robotInfo.nickname          = RobotInfoVO.key
            robotInfo.isRobot           = true

            robotInfo.chargeStatus      = true
            robotInfo.deviceFishTreasure= 0
            robotInfo.deviceGold        = 0
            robotInfo.deviceNotFishGold = 0
            robotInfo.deviceRoleCount   = 1
            robotInfo.fishTreasure      = 1
            robotInfo.isVip             = true
            robotInfo.notFishGold       = 0
            robotInfo.novice            = 0
            robotInfo.stock             = 0
            robotInfo.totalCostGold     = 0

            
            robotInfo.gold              = 1000--math.floor(math.rand(RobotCathFishVO.gold[1], RobotCathFishVO.gold[2]) / 10) * 10
            robotInfo.goldUpperLimit    = robotInfo.gold + RobotCathFishVO.exit_add_gold    -- 金币高于该值时退出
            robotInfo.goldLowerLimit    = robotInfo.gold - RobotCathFishVO.exit_lose_gold   -- 金币低于该值时退出
            robotInfo.gunLevel          = 10
            robotInfo.gunType           = RobotCathFishVO.gun_type[math.rand(1, 10000) % table.nums(RobotCathFishVO.gun_type) + 1]
            robotInfo.hitRatio          = math.floor(math.rand(RobotCathFishVO.hitRatio[1], RobotCathFishVO.hitRatio[2]))
            robotInfo.exitTime          = RobotCathFishVO.exit_time * 60
            robotInfo.treasureCost      = {math.floor(math.rand(RobotCathFishVO.treasureCost[1], RobotCathFishVO.treasureCost[2])), 0}
            
            -- 机器人正常炮倍数
            robotInfo.normalGunLevel    = RobotCathFishVO.gun_level[math.rand(1, 10000) % table.nums(RobotCathFishVO.gun_level) + 1]
            -- 开炮方式：1，自动发炮；2，随机发炮
            robotInfo.autoFishType      = math.rand(100) % 2
            -- 进入房间等待 X 个发炮间隔，0.2秒
            robotInfo.pauseTimes         = math.floor(math.rand(RobotCathFishVO.ready_time[1], RobotCathFishVO.ready_time[2])) * 5
            -- 发 X 炮，停顿 Y 个发炮间隔
            robotInfo.pause             = {
                        math.floor(math.rand(RobotCathFishVO.pause_time[1][1], RobotCathFishVO.pause_time[1][2])), 
                        math.floor(math.rand(RobotCathFishVO.pause_time[2][1], RobotCathFishVO.pause_time[2][2])) * 5
                    }

            RobotPool[robotId] = robotInfo
        end
    end
end

return CathFishRobotMgr