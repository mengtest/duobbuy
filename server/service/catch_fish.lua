local skynet = require("skynet")
local json = require("json")
local logger = require("log")
local context = require("common.context")
local protoMap = require("proto_map")
local dbHelp = require("common.db_help")

local command =  require("command_base")

local GameConfig = require("config.game_config")
local CatchFishConst = require("catch_fish.catch_fish_const")
local RoomType = CatchFishConst.RoomType

local SYNC_INTERVAL = 1          --游戏设置数据同步间隔
local svcCount = tonumber(skynet.getenv("svcCount"))
local svcAllocThreshold = tonumber(skynet.getenv("svcAllocThreshold")) or 16

local settings = {
    protect = true,
    maxGoldOfFreePlayer = 19800,    --免费玩家最大金币数
}

local svcs = {}
local vipSvc
local arenaSvc
local roles = {}
local totalPlayerCount = 0

local isTestBoss = tonumber(skynet.getenv("isTestBoss")) == 1
local INIT_BOSS_AP = tonumber(skynet.getenv("initBossAp")) or 50000000
local enableBoss = tonumber(skynet.getenv("enableBoss")) == 1
local bossAp = 0
local bossCost = 0
local bossPump = 0.1

local function initSvcPool()
    for i = 1, svcCount do
        local svc = skynet.newservice("catch_fish_svc")
        context.callS2S(svc, "init", RoomType.NORMAL, settings)
        svcs[#svcs + 1] = {svc = svc, playerCount = 0, type = RoomType.NORMAL}
    end
    
    local svc = skynet.newservice("catch_fish_svc")
    context.callS2S(svc, "init", RoomType.VIP, settings)
    vipSvc = {svc = svc, playerCount = 0, type = RoomType.VIP}

    local svc = skynet.newservice("catch_fish_svc")
    context.callS2S(svc, "init", RoomType.ARENA, settings)
    arenaSvc = {svc = svc, playerCount = 0, type = RoomType.ARENA}
end

local function getSvc()
    for _, svcInfo in ipairs(svcs) do
        if svcInfo.playerCount < svcAllocThreshold then
            return svcInfo
        end
    end

    local index = math.rand(1, #svcs)
    local svcInfo = svcs[index]
    return svcInfo
end

local function onEnter(svcInfo, roleId, roomInfo)
    roles[roleId] = svcInfo
    svcInfo.playerCount = svcInfo.playerCount + 1
    totalPlayerCount = totalPlayerCount + 1

    -- logger.Pf("enter: type:%s, svc:%d, playCount:%d", svcInfo.type, svcInfo.svc, svcInfo.playerCount)
end

local lastVirtualPlayerCount
function command.getClassicsRoomPlayer()
    local virtualPlayerCountIndex = GameConfig.virtualPlayerCount or {}
    local hour = os.date("%H") + 1
    local newVirtualPlayerCount = virtualPlayerCountIndex[hour] or 0
    local virtualPlayerUndulate = GameConfig.virtualPlayerUndulate
    if math.abs(newVirtualPlayerCount - (lastVirtualPlayerCount or newVirtualPlayerCount)) > virtualPlayerUndulate then
        if lastVirtualPlayerCount > newVirtualPlayerCount then
            lastVirtualPlayerCount = newVirtualPlayerCount - virtualPlayerUndulate
        else
            lastVirtualPlayerCount = newVirtualPlayerCount + virtualPlayerUndulate
        end
    else
        lastVirtualPlayerCount = newVirtualPlayerCount
    end

    local virtualPlayerCount = lastVirtualPlayerCount + totalPlayerCount ^ 1.2
    virtualPlayerCount = virtualPlayerCount + math.rand(1,30)
    virtualPlayerCount = math.floor(virtualPlayerCount)
    return virtualPlayerCount
end

local function castPlayerCountInfo()
    local virtualPlayerCount = command.getClassicsRoomPlayer()
    -- context.castS2C(nil, M_CatchFish.handleTotalPlayerUpdate, virtualPlayerCount)
    context.castS2C(nil, M_LOBBY.syncLobbyInfo, {classicsRoomPlayer = virtualPlayerCount})

    local updatePlayerCountInterval = GameConfig.updatePlayerCountInterval or 5
    skynet.timeout(updatePlayerCountInterval * 100, castPlayerCountInfo)
end

function command.enter(enterInfo)
    if roles[enterInfo.roleId] then
        return SystemError.illegalOperation
    end

    local svcInfo = getSvc()
    local ec, roomInfo = context.callS2S(svcInfo.svc, "enter", enterInfo)
    if ec ~= SystemError.success then
        return ec
    end

    onEnter(svcInfo, enterInfo.roleId, roomInfo)

    return ec, svcInfo.svc, roomInfo
end

function command.leave(roleId)
    local svcInfo = roles[roleId]
    if not svcInfo then
        return SystemError.success
    end

    roles[roleId] = nil
    totalPlayerCount = totalPlayerCount - 1


    svcInfo.playerCount = svcInfo.playerCount - 1
    -- logger.Pf("leave: type:%s, svc:%d, playCount:%d", svcInfo.type, svcInfo.svc, svcInfo.playerCount)

    return context.callS2S(svcInfo.svc, "leave", roleId)
end

function command.createVipRoom(createInfo)
    local svcInfo = roles[createInfo.roleId]
    if svcInfo then
        command.leave(createInfo.roleId)
    end

    local ec, roomInfo = context.callS2S(vipSvc.svc, "createVip", createInfo)
    if ec ~= SystemError.success then
        return ec
    end

    onEnter(vipSvc, createInfo.roleId, roomInfo)

    return ec, vipSvc.svc, roomInfo
end

function command.enterVipRoom(enterInfo)
    local ec, roomInfo =  context.callS2S(vipSvc.svc, "enterVip", enterInfo)
    if ec ~= SystemError.success then
        return ec
    end

    local svcInfo = roles[enterInfo.roleId]
    if svcInfo then
        if svcInfo == vipSvc then
            totalPlayerCount = totalPlayerCount - 1
        else
            command.leave(enterInfo.roleId)
        end
    end

    onEnter(vipSvc, enterInfo.roleId, roomInfo)

    return ec, vipSvc.svc, roomInfo
end

function command.getVipRoomList()
    local ec, roomList =  context.callS2S(vipSvc.svc, "getVipRoomList")
    if ec ~= SystemError.success then
        return ec
    end
    return ec, roomList
end

--[[
    获取竞技场信息 
    @result 返回指定类型所有等级当前报名信息
]]
function command.getArenaList(roleId)
    return context.callS2S(arenaSvc.svc, "getArenaList", roleId)
end

--[[
    报名指定竞技场 
]]
function command.joinArena(info)
    local ec, roomId = context.callS2S(arenaSvc.svc, "joinArena", info)
    if ec ~= SystemError.success then
        return ec
    end
    return ec, roomId
end

--[[
    取消报名
    @param roleId 角色ID
]]
function command.cancelJoinArena(roleId)
    return context.callS2S(arenaSvc.svc, "cancelJoinArena", roleId)
end

function command.getJoinArena(roleId)
    return context.callS2S(arenaSvc.svc, "getJoinArena", roleId)
end

function command.getArena(roomId)
    return context.callS2S(arenaSvc.svc, "getArena", roomId)
end 

--[[
    进入指定竞技场 
    @param enterInfo 包含进入房间信息以及玩家信息
]]
function command.enterArena(enterInfo)
    local ec, roomInfo = context.callS2S(arenaSvc.svc, "enterArena", enterInfo)
    if ec ~= SystemError.success then
        return ec
    end

    local svcInfo = roles[enterInfo.roleId]
    if svcInfo then
        if svcInfo == arenaSvc then
            totalPlayerCount = totalPlayerCount - 1
        else
            command.leave(enterInfo.roleId)
        end
    end

    onEnter(arenaSvc, enterInfo.roleId, roomInfo)

    return ec, arenaSvc.svc, roomInfo
end

--[[
    获取此玩家正在进行中的竞技比赛房间ID
    @param roleId 角色ID
]]
function command.getDoingArena(roleId)
    return context.callS2S(arenaSvc.svc, "getDoingArena", roleId)
end

--[[
    放弃比赛
    @param roleId 角色ID
]]
function command.giveUpArena(roleId, roomId)
    local ec = context.callS2S(arenaSvc.svc, "giveUpArena", roleId, roomId)
    if ec ~= SystemError.success then
        return ec
    end

    local svcInfo = roles[roleId]
    if svcInfo == arenaSvc then
        roles[roleId] = nil
        totalPlayerCount = totalPlayerCount - 1
        arenaSvc.playerCount = arenaSvc.playerCount - 1
        return ec, arenaSvc.svc
    end
    return ec
end

-------------------------------------------------------------
local FishPathConf = require("config.fish_path")
local FishPathGroupConf = require("config.fish_path_group")
local FishGroupConf = require("config.fish_group")
local FishGroupTypeConf = require("config.fish_group_type")
local BossRefreshConf = require("config.boss_refresh")
local prizeConf = require("config.prize")
local bosses = {}
local bossId = 0
local bossRefreshStates = {}
local isEnabledBoss = true
local function getBossId()
    bossId = bossId + 1
    if bossId >= 1024 then
        bossId = 1
    end
    return bossId << 21
end

local function doSyncBossAp()
    local ratio = 1 + bossAp / INIT_BOSS_AP
    for _, svcInfo in pairs(svcs) do
        context.sendS2S(svcInfo.svc, "updateBossAp", ratio)
    end
    context.sendS2S(vipSvc.svc, "updateBossAp", ratio)

    dbHelp.send("boss.updateBossInfo", bossAp, bossCost)
end

local function syncBossAp()
    doSyncBossAp()
    skynet.timeout(SYNC_INTERVAL * 100, syncBossAp)
end

local function initBossAp()
    if not command.bossIsOpen() then
        return
    end
    for _, item in ipairs(BossRefreshConf) do
        bossRefreshStates[item.type] = 0
    end
    local bossInfo = dbHelp.call("boss.getBossInfo")
    bossAp = bossInfo.bossAp
    bossCost = bossInfo.bossCost
    print(string.format("initBossInfo, bossInfo:{bossAp:%s,bossCost:%s}", bossAp, bossCost))
    syncBossAp()
    command.bornBosses()
end

local function fishBorn(type)
    local now = skynet.time()

    --随机鱼类型
    local fishGroups = FishGroupTypeConf[type]
    local groupId = fishGroups[math.rand(1, #fishGroups)]
    local fishGroup = FishGroupConf[groupId]
    
    --随机选择游动路线
    local pathGroups = FishPathGroupConf[fishGroup.pathGroup]
    local pathId = pathGroups[math.rand(1, #pathGroups)]
    local path = FishPathConf[pathId]
    
    local bornCount = 0
    local curdelay = 0
    local curRotation = 0
    local fishes = {}
    while bornCount < fishGroup.count do
        for _, rule in ipairs(fishGroup.bornRule) do
            local type, count, interval, rotation, children = table.unpack(rule)
            rotation = math.rad(rotation or 0)
            count = math.min(fishGroup.count - bornCount, math.max(1, count))
            for i = 1, count do
                local fish = {
                        objectId = getBossId(),
                        type = type,
                        pathId = path.id,
                        rotation = curRotation,
                        bornTime = now + curdelay,
                        aliveTime = -curdelay,
                        children = children,
                        prizeId = children[1],
                    }
                fishes[fish.objectId] = fish
                curdelay = curdelay + interval
                curRotation = curRotation + rotation
                bornCount = bornCount + 1
            end
            if bornCount == fishGroup.count then
                break
            end
        end
    end

    return fishes
end

function command.setInitBossAp(initBossAp)
    INIT_BOSS_AP = initBossAp
    doSyncBossAp()
end

function command.enabledBoss(value)
    enableBoss = value
end

function command.bossIsOpen()
    return enableBoss
end

function command.bornBosses()
    --根据当前时间获取对应配置
    local dt = 2
    skynet.timeout(dt * 100, function()
        if not command.bossIsOpen() then
            return
        end
        command.bornBosses()

        local date = os.date("*t")
        local now = os.time()
        local refreshTypes = {}
        for _, item in ipairs(BossRefreshConf) do
            if now - bossRefreshStates[item.type] >= item.interval then
                bossRefreshStates[item.type] = now
                if isTestBoss then
                    refreshTypes[item.type] = true
                else
                    if table.indexof(item.week, date.wday, nil, true) then
                        for _, d in ipairs(item.day) do
                            if date.hour * 60 + date.min >= d[1] 
                                and date.hour * 60 + date.min <= d[2] then
                                refreshTypes[item.type] = true
                            end
                        end
                    else
                        bossRefreshStates[item.type] = 0
                    end
                end
            end
        end

        --创建Boss对象信息
        local fishes = {}
        for type in pairs(refreshTypes) do
            local items = fishBorn(type)
            if not table.empty(items) then
                table.merge(fishes, items)
                table.merge(bosses, items)
            end
        end

        if not table.empty(fishes) then
            --同步到各个房间
            for _, svcInfo in pairs(svcs) do
                context.sendS2S(svcInfo.svc, "bornBosses", fishes)
            end
            context.sendS2S(vipSvc.svc, "bornBosses", fishes)
        end
    end)
    
end

function command.killBoss(info)
    local boss = bosses[info.objectId]
    if not boss then
        return
    end

    local conf = prizeConf[boss.prizeId]

    --更新同步Boss奖池
    bossAp = bossAp - conf.worth
    doSyncBossAp()

    --从各个房间移除对应boss对象
    for _, svcInfo in pairs(svcs) do
        context.sendS2S(svcInfo.svc, "killBoss", info.objectId)
    end
    context.sendS2S(vipSvc.svc, "killBoss", info.objectId)
    --发送击杀广播
    context.castS2C(nil, M_Boss.handleKillBoss, {roleId = info.roleId, bossId = info.objectId})
    --保存击杀信息到数据库
    dbHelp.send("boss.addKillInfo", {prizeId = boss.prizeId, roleId = info.roleId
            , nickname = info.nickname, goodsId = conf.prizeId})

    --发送跑马灯
    context.castS2C(nil, M_Marquee.handleSendMsgByKeyWord, {id = 10, words = {info.nickname, conf.name}})
end

function command.updateBossAp(costNotFishGold)
    bossAp = bossAp + costNotFishGold * bossPump
    bossCost = bossCost + costNotFishGold
end

-------------------------------------------------------------
function command.setSetting(type, value)
    settings[type] = value
    logger.Pf("setSeting, type[%s], value[%s]", type, value)

    for _, svcInfo in pairs(svcs) do
        context.sendS2S(svcInfo.svc, "setSetting", type, value)
    end
    context.sendS2S(vipSvc.svc, "setSetting", type, value)
end

function command.getSetting(type, value)
    return settings[type]
end

function command.getAllSettings()
    return settings
end

local function printCatchFishInfo()
    skynet.timeout(30 * 100, function() printCatchFishInfo() end)
    -- if table.nums(roles) == 0 then return end

    local totalInfo = {robotNum = 0, roomNum = 0}
    for _, svcInfo in ipairs(svcs) do
        local info = context.callS2S(svcInfo.svc, "getCathFishSvcInfo") or {}
        totalInfo.robotNum = totalInfo.robotNum + (info.robotNum or 0)
        totalInfo.roomNum = totalInfo.roomNum + (info.roomNum or 0)
    end
    local info = context.callS2S(vipSvc.svc, "getCathFishSvcInfo") or {}
    totalInfo.robotNum = totalInfo.robotNum + (info.robotNum or 0)
    totalInfo.roomNum = totalInfo.roomNum + (info.roomNum or 0)

    logger.Pf("...fish...roomNum:%s robotNum:%s rolesNum:%s", totalInfo.roomNum, totalInfo.robotNum, table.nums(roles))
end

skynet.start(function()
    initSvcPool()
    skynet.register(SERVICE.CATCH_FISH)
    skynet.timeout(2 * 100, initBossAp)
    skynet.timeout(2 * 100, castPlayerCountInfo)
    print("catch fish server start")
    printCatchFishInfo()

    if isTestBoss then
        print("*********************************************")
        print("WARNING！ The boss activity is test mode now.")
        print("*********************************************")
    end
end)