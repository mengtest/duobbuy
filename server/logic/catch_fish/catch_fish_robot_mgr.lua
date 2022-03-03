local table = table
local math = math
local skynet = require("skynet")
local logger = require("log")
local context = require("common.context")

local RobotInfoConfig = require("config.robot_info")
local RobotCathFishConfig = require("config.robot_cath_fish")

local CatchFishRobotMgr = {}
local RobotPool = {}

-- 初始机器人
function CatchFishRobotMgr.initRobot()
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
            robotInfo.level             = 10

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

            
            robotInfo.gold              = math.floor(math.rand(RobotCathFishVO.gold[1], RobotCathFishVO.gold[2]) / 10) * 10
            robotInfo.costGold          = 10000
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

function CatchFishRobotMgr.getRobtoNum()
    local robotNum = 0
    for robotId,RobotInfo in pairs(RobotPool) do
        if RobotInfo.roomId then
            robotNum = robotNum + 1
        end
    end
    return robotNum
end

-- 获得机器人
-- 条件
-- {
-- minGunLevel 最小炮塔等级
-- gunType     指定炮塔类型
-- gunLevel    指定炮塔等级
-- }
function CatchFishRobotMgr.getRobot(screening, replace)
    if CatchFishRobotMgr.getRobtoNum() >= 100 then
        return
    end
    
    if not screening or table.empty(screening) then
        screening = {1}
    end 

    -- 过滤机器人
    function filterFunc(RobotInfo, condition)
        if condition.minGunLevel and RobotInfo.normalGunLevel < condition.minGunLevel then 
            return false
        end
        if condition.gunType and RobotInfo.gunType ~= condition.gunType then 
            return false
        end 
        if condition.gunLevel and RobotInfo.normalGunLevel ~= condition.gunLevel then 
            return false
        end 
        return true
    end

    local robotList = {}
    for robotId,RobotInfo in pairs(RobotPool) do
        if not RobotInfo.roomId then 
             for k,v in pairs(screening) do
                local condition = {}
                condition[k] = v
                if filterFunc(RobotInfo, condition) then 
                    table.insert(robotList, robotId)
                end 
            end
        end
    end 
    if table.empty(robotList) then 
        return
    end 
    local robotId = robotList[math.floor(math.rand(1, 10000)) % table.nums(robotList) + 1]
    local robot = clone(RobotPool[robotId])
    for k,v in pairs(replace or {}) do
        robot[k] = v
    end
    return robot
end

function CatchFishRobotMgr.setRobotRoom(robotId, roomId)
    local robotInfo = RobotPool[robotId]
    if robotInfo then 
        robotInfo.roomId = roomId
    end
end 

-- 获得相近的等级
-- levelList 有序，且从小到大
function CatchFishRobotMgr.getNearLevel(level, levelList, operation)
    if not level then return 10 end 
    if not levelList then return level end
    if not operation then return level end 

    if operation == "<" then
        for i,other in ipairs(levelList) do
            if other <= level then
                return levelList[i - 1] or level
            end 
        end
    elseif operation == "<=" then
        for i,other in ipairs(levelList) do
            if other == level then
                return level
            elseif other < level then
                return levelList[i - 1] or level
            end 
        end
    elseif operation == ">=" then
        for i,other in ipairs(levelList) do
            if other == level then
                return level
            elseif other > level then
                return other
            end 
        end
    elseif operation == ">" then
        for i,other in ipairs(levelList) do
            if other > level then
                return other
            end 
        end
    end 
    return level
end 

function CatchFishRobotMgr.getVipRoomMaxGunLevel(RobotInfo)
    local gunLevelIndex = {10,100,200,500,1000,2000,5000}
    local maxGunLevel = 10
    for _,gunLevel in pairs(gunLevelIndex) do
        if RobotInfo.gunLevel >= gunLevel and gunLevel > maxGunLevel then
            maxGunLevel = gunLevel
        end
    end
    return maxGunLevel
end

return CatchFishRobotMgr