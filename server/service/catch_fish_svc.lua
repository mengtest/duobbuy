local table = table
local skynet = require("skynet")
local json = require("json")
local logger = require("log")
local context = require("common.context")
local protoMap = require("proto_map")
local dbHelp = require("common.db_help")
local Room = require("catch_fish.room")
local VipRoom = require("catch_fish.vip_room")
local ArenaRoom = require("catch_fish.arena_room")
local CatchFishRobotMgr = require("catch_fish.catch_fish_robot_mgr")

local arenaConfig = require("config.arena_config")
local RobotInfoConfig = require("config.robot_info")
local RobotCathFishConfig = require("config.robot_cath_fish")

local CatchFishConst = require("catch_fish.catch_fish_const")
local ArenaType = CatchFishConst.ArenaType
local ArenaLevel = CatchFishConst.ArenaLevel
local RoomType = CatchFishConst.RoomType
local PlayerState = CatchFishConst.PlayerState

local command =  require("command_base")

local sendMarquee = tonumber(skynet.getenv("sendMarquee")) or 0

local TICK_INTERVAL = 10
local ROBOT_INTERVAL = 500
local PUMP_RATIO = tonumber(skynet.getenv("pump")) or 0.2

-- 机器人相关
local GameConfig = require("config.game_config")
local OPEN_ROBOT = (GameConfig.open_robot or 0) == 1
local UPDATE_ROOM_INTERVAL = GameConfig.updateRoomInterval
local NORMAL_ROOM_NUM = GameConfig.normalRoomNum
local VIP_ROOM_NUM = GameConfig.vipRoomNum
local PWD_ROOM_NUM = GameConfig.pwdRoomNum
local PEAK_TIME_LIST = GameConfig.peakTimeList
local FIRE_INTERVAL = GameConfig.fireInterval

local settings = {}

local roomType
local nextRoomId = 1
local prevUpdateTime = 0
local rooms = {}
local roles = {}
local awardPoolAddition = 0
local roomCount = 0

local arenaList = {}
local joinArenas = {}

local bosses = {}
local bossAp = 1

local registerRoleIndex = {}


local function getArenaConf(type, level)
    for _, item in ipairs(arenaConfig) do
        if item.type == type and item.level == level then
            return item
        end
    end
end

local function allocRoomId()
    local roomId = 1
    while true do
        if not rooms[roomId] and not arenaList[roomId] then
            return roomId
        end
        roomId = roomId + 1
    end
end

local function getRoom()
    for _, room in pairs(rooms) do
        if room:hasEmptyPos() then
            return room
        end
    end

    local room = Room.new({
            roomId = nextRoomId,
            sendMarquee = sendMarquee,
            protect = settings.protect,
            maxGoldOfFreePlayer = settings.maxGoldOfFreePlayer,
        })
    rooms[nextRoomId] = room
    nextRoomId = nextRoomId + 1

    room:bornBosses(bosses, false)

    roomCount = roomCount + 1

    return room
end

local function getRobotRoom()
    for _, room in pairs(rooms) do
        if room:hasEmptyPos() and room:getPlayerNum() < 5 then
            return room
        end
    end

    local room = Room.new({
            roomId = nextRoomId,
            sendMarquee = sendMarquee,
            protect = settings.protect,
            maxGoldOfFreePlayer = settings.maxGoldOfFreePlayer,
        })
    rooms[nextRoomId] = room
    nextRoomId = nextRoomId + 1

    room:bornBosses(bosses, false)

    roomCount = roomCount + 1

    return room
end

local function getEmptyRoom()
    for _, room in pairs(rooms) do
        if room:isEmpty() then
            return room
        end
    end

    local room = Room.new({
            roomId = nextRoomId,
            sendMarquee = sendMarquee,
            protect = settings.protect,
            maxGoldOfFreePlayer = settings.maxGoldOfFreePlayer,
        })
    rooms[nextRoomId] = room
    nextRoomId = nextRoomId + 1

    room:bornBosses(bosses, false)

    roomCount = roomCount + 1

    return room
end

local function initArena(info)
    local arena = {roomId = allocRoomId(), type = info.type, level = info.level
        , password = info.password or "", players = {}, positions = {}}
    arenaList[arena.roomId] = arena
    return arena
end

function command.init(type, allSettings)
    roomType = type
    settings = allSettings

    -- 创建机器人房间
    -- if false then
    if OPEN_ROBOT then
        -- 普通房间和 VIP 房间允许生成机器人
        if roomType ~= RoomType.NORMAL 
            and roomType ~= RoomType.VIP then 
            return
        end

        -- 初始化机器人
        CatchFishRobotMgr.initRobot()
        if roomType == RoomType.NORMAL then
            command.dispatchNormalRoom()
        elseif roomType == RoomType.VIP then
            command.dispatchVIPRoom()
        end
        command.dispatchAddRobot()
        command.dispatchLeavingRobot()
        command.dispatchRobot()
    end
end

function command.isInit()
    return not table.empty(settings)
end

function command.updateGold(roleId, gold, exclude)
    local room = roles[roleId]
    if room then
        room:updateGold(roleId, gold, exclude)
    end
end

function command.updateRoleInfo(roleId, updateInfo, exclude)
    local room = roles[roleId]
    if room then
        room:updateRoleInfo(roleId, updateInfo, exclude)
    end
end

function command.updateNotFishGold(roleId, notFishGold, noviceGold, chargeStatus)
    local room = roles[roleId]
    if room then
        room:updateNotFishGold(roleId, notFishGold, noviceGold, chargeStatus)
    end
end

function command.updateVip(roleId, isVip)
    local room = roles[roleId]
    if room then
        room:updateVip(roleId, isVip)
    end
end

function command.updateAwardPool(addition)
    awardPoolAddition = addition
end

function command.enter(enterInfo)
    local room
    if enterInfo.roomId then
        room = rooms[enterInfo.roomId]
        if roomType == RoomType.VIP then
            command.leave(enterInfo.roleId)
        end
    else
        -- room = getRoom()
        enterInfo.isNewPlayer = false
        if enterInfo.isNewPlayer then 
            room = getEmptyRoom()
            local gunLevelList = {200,300,400,500,600,700,800,900,1000}
            local gunlevel = gunLevelList[math.rand(1, #gunLevelList)]
            command.addRobotToRoom(room, true, {gunLevel = gunlevel}, {gunType = 5, gunLevel = gunlevel})
            gunlevel = gunLevelList[math.rand(1, #gunLevelList)]
            command.addRobotToRoom(room, true, {gunLevel = 500}, {gunType = 3, gunLevel = 500})
        else 
            room = getRobotRoom()
        end 
    end

    -- logger.Pf("svc:%d, enter, roomCount:%d", skynet.self(), roomCount)
    
    room:addPlayer(enterInfo)
    roles[enterInfo.roleId] = room
    local roomInfo = room:getRoomInfo()

    if room:isVip() then
        command.onUpdateVipRoom(room)
    end
    return SystemError.success, roomInfo
end

function command.leave(roleId)
    local room = roles[roleId]
    if room then
        -- 处理机器人离开房间
        CatchFishRobotMgr.setRobotRoom(roleId, nil)
        if roomType == RoomType.ARENA then
            room:leave(roleId)
        else
            room:removePlayer(roleId)
            roles[roleId] = nil
            if room:isEmpty() then
                rooms[room:getRoomId()] = nil
                -- VIP 房间销毁
                if room:isVip() then
                    command.onDestroyVipRoom(room:getRoomId())
                end
                room:destroy()
                roomCount = roomCount - 1
                -- logger.Pf("svc:%d, destroy, roomCount:%d", skynet.self(), roomCount)
            else
                if room:isVip() then
                    command.onUpdateVipRoom(room)
                end
            end
        end
    end
    return SystemError.success
end

function command.fire(fireInfo, cost)
    local room = roles[fireInfo.roleId]
    if not room then
        if roomType == RoomType.ARENA then
            return CatchFishError.arenaIsOver
        else
            return SystemError.illegalOperation
        end
    end

    return room:fire(fireInfo, cost)
end

function command.hit(hitInfo)
    local room = roles[hitInfo.roleId]
    if not room then
        if roomType == RoomType.ARENA then
            return CatchFishError.arenaIsOver
        else
            return SystemError.illegalOperation
        end
    end
    hitInfo.pumpRatio = -PUMP_RATIO
    hitInfo.bossAp = bossAp
    return room:hit(hitInfo)
end

function command.robotHit(roleId, hitInfo)
    local room = roles[roleId]
    if not room then
        if roomType == RoomType.ARENA then
            return CatchFishError.arenaIsOver
        else
            return SystemError.illegalOperation
        end
    end
    hitInfo.pumpRatio = -PUMP_RATIO
    hitInfo.bossAp = bossAp
    return room:robotHit(hitInfo)
end

function command.aim(aimInfo)
    local room = roles[aimInfo.roleId]
    if not room then
        return SystemError.illegalOperation
    end
    return room:aim(aimInfo)
end

function command.stopAim(roleId)
    local room = roles[roleId]
    if not room then
        return SystemError.illegalOperation
    end
    return room:stopAim(roleId)
end

function command.updateGun(gunInfo)
    local room = roles[gunInfo.roleId]
    if not room then
        return SystemError.illegalOperation
    end
    return room:updateGun(gunInfo)
end

function command.freeze(roleId)
    local room = roles[roleId]
    if not room then
        return SystemError.illegalOperation
    end

    return room:freeze(roleId)
end

function command.crit(roleId)
    local room = roles[roleId]
    if not room then
        return SystemError.illegalOperation
    end

    return room:crit(roleId)
end

function command.slice(roleId, sliceInfo)
    local room = roles[roleId]
    if not room then
        return SystemError.illegalOperation
    end
    sliceInfo.pumpRatio = -PUMP_RATIO
    sliceInfo.bossAp = bossAp
    return room:slice(roleId, sliceInfo)
end

function command.uncrit(roleId)
    local room = roles[roleId]
    if not room then
        return SystemError.illegalOperation
    end

    return room:uncrit(roleId)
end

function command.chat(chatInfo)
    local room = roles[chatInfo.sender]
    if not room then
        return SystemError.illegalOperation
    end
    room:chat(chatInfo)
    return SystemError.success
end

function command.cast(roleId, proto, data, exclude)
    local room = roles[roleId]
    if not room then
        return SystemError.illegalOperation
    end
    room:cast(proto, data, exclude)
    return SystemError.success
end

function command.createVip(createInfo)
    local room = roles[createInfo.roleId]
    if room then
        return SystemError.illegalOperation
    end
    
    local roomId = allocRoomId()
    local room = VipRoom.new({
                roomId = roomId,
                sendMarquee = sendMarquee,
                protect = settings.protect,
                password = createInfo.password,
                minGunLevel = createInfo.minGunLevel,
                maxGoldOfFreePlayer = settings.maxGoldOfFreePlayer,
            })

    rooms[roomId] = room
    roles[createInfo.roleId] = room
    room:addPlayer(createInfo)
    roomCount = roomCount + 1

    room:bornBosses(bosses, false)

    local roomInfo = room:getRoomInfo()
    -- 通知创建 VIP 房间
    command.onUpdateVipRoom(roomInfo)
    return SystemError.success, roomInfo
end

function command.enterVip(enterInfo)
    local room = rooms[enterInfo.roomId]
    if not room then
        return CatchFishError.roomNotFound
    end

    if not room:hasEmptyPos() then
        return CatchFishError.roomIsFull
    end

    if enterInfo.password ~= room:getPassword() then
        return CatchFishError.passwordWrong
    end

    local ec, roomInfo = command.enter(enterInfo)

    return ec, roomInfo
end

function command.getVipRoomList()
    local roomList = {}
    for _, room in pairs(rooms) do
        if room:isVip() then
            roomList[#roomList + 1] = room:getVipRoomInfo() 
        end
    end
    return SystemError.success, roomList
end

function command.registerVipRoom(roleId)
    registerRoleIndex[roleId] = true
    return command.getVipRoomList()
end

function command.unregisterVipRoom(roleId)
    registerRoleIndex[roleId] = nil
end

function command.onUpdateVipRoom(roomInfo)
    for roleId,_ in pairs(registerRoleIndex) do
        context.sendS2C(roleId, M_CatchFish.onUpdateVipRoom, roomInfo)
    end
end

function command.onDestroyVipRoom(roomId)
    for roleId,_ in pairs(registerRoleIndex) do
        context.sendS2C(roleId, M_CatchFish.onDestroyVipRoom, roomId)
    end
end
----------------------------------------------------------------
function command.getArenaList(roleId)
    local joinInfos = {myRoomId = 0, rooms = {}}
    for roomId, arena in pairs(arenaList) do
        local item = {roomId = arena.roomId, type = arena.type
            , level = arena.level, password = arena.password
            , players = {}, isBegan = arena.isBegan}
        joinInfos.rooms[#joinInfos.rooms + 1] = item
        for playerId, player in pairs(arena.players) do
            item.players[#item.players + 1]
                = {roleId = player.roleId, avatar = player.avatar, pos = player.pos}
            if playerId == roleId then
                joinInfos.myRoomId = roomId
            end
        end
    end
    return SystemError.success, joinInfos
end

local function getArenaRoomInfo(roomId)
    local arena = arenaList[roomId]
    local info = {}
    info.roomId = roomId
    info.type = arena.type
    info.level = arena.level
    info.password = arena.password
    info.isBegan = arena.isBegan
    info.players = {}
    for roleId, player in pairs(arena.players) do
        info.players[#info.players + 1] = {roleId = roleId, avatar = player.avatar, pos = player.pos}
    end
    return info
end

function command.joinArena(info)
    if roles[info.roleId] then
        return CatchFishError.isInArena
    end

    local arena
    if info.roomId > 0 then
        arena = arenaList[info.roomId]
        if not arena then
            return CatchFishError.roomNotFound
        end
        if table.nums(arena.players) >= CatchFishConst.ROOM_PLAYER_COUNT then
            return CatchFishError.roomIsFull
        end
    else
        arena = initArena(info)
    end

    for pos = 1, CatchFishConst.ROOM_PLAYER_COUNT do
        if not arena.positions[pos] then
            info.pos = pos
            arena.positions[pos] = true
            break
        end
    end
    
    arena.players[info.roleId] = info
    joinArenas[info.roleId] = arena

    local roomId = arena.roomId

    local conf = getArenaConf(info.type, info.level)
    
    --记录暂扣的赌注
    dbHelp.call("catchFish.freezeBet", info.roleId, conf.bet.goodsId, conf.bet.amount)

    if table.nums(arena.players) >= CatchFishConst.ROOM_PLAYER_COUNT then
         arena.isBegan = true
    end

    local joinInfo = getArenaRoomInfo(roomId)
    context.castS2C(nil, M_CatchFish.handleJoinArenaInfoUpdate, joinInfo)

    if not arena.isBegan then
        return SystemError.success, roomId
    end

    local room = ArenaRoom.new({
                roomId = roomId,
                sendMarquee = sendMarquee,
                arena = arena,
            })
    rooms[roomId] = room
    roomCount = roomCount + 1

    --清除暂扣赌注记录
    for roleId in pairs(arena.players) do
        dbHelp.send("catchFish.deleteBet", roleId)
    end

    return SystemError.success, roomId
end

function command.cancelJoinArena(roleId)
    local arena = joinArenas[roleId]
    if arena then
        if arena.isBegan then
            return CatchFishError.isInArena
        end
        local player = arena.players[roleId]
        arena.positions[player.pos] = nil
        arena.players[roleId] = nil
        joinArenas[roleId] = nil

        local joinInfo = getArenaRoomInfo(arena.roomId)
        context.castS2C(nil, M_CatchFish.handleJoinArenaInfoUpdate, joinInfo)
        if table.nums(arena.players) == 0 then
            arenaList[arena.roomId] = nil
        end
    end
    return SystemError.success
end

function command.getArena(roomId)
    return arenaList[roomId]
end 

function command.getJoinArena(roleId)
    return joinArenas[roleId]
end

function command.enterArena(enterInfo)
    local room = rooms[enterInfo.roomId]
    if not room then
        return CatchFishError.roomNotFound
    end

    if not room:canEnter(enterInfo.roleId) then
        return SystemError.illegalOperation
    end

    local ec, roomInfo = command.enter(enterInfo)
    return ec, roomInfo
end

function command.getDoingArena(roleId)
    local room = roles[roleId]
    if not room then
        local arena = joinArenas[roleId]
        if arena and arena.isBegan then
            room = rooms[arena.roomId]
        end
    end
    if room then
        local info = {}
        info.roomId = room:getRoomId()
        info.type = room:getArenaType()
        info.level = room:getArenaLevel()
        return SystemError.success, info
    end
    return SystemError.success, {}
end

function command.giveUpArena(roleId, roomId)
    local room = rooms[roomId]
    if room then
        local ec = room:giveUp(roleId)
        if ec ~= SystemError.success then
            return ec
        end
        roles[roleId] = nil
        joinArenas[roleId] = nil

        local arena = arenaList[roomId]
        local player = arena.players[roleId]
        arena.positions[player.pos] = nil
        arena.players[roleId] = nil
        local joinInfo = getArenaRoomInfo(arena.roomId)
        context.castS2C(nil, M_CatchFish.handleJoinArenaInfoUpdate, joinInfo)

        return SystemError.success
    end
    return SystemError.illegalOperation
end
------------------------------------------------------------------
function command.updateBossAp(ratio)
    bossAp = ratio
end

function command.bornBosses(bossInfos)
    table.merge(bosses, bossInfos)
    for _, room in pairs(rooms) do
        room:bornBosses(bossInfos, true)
    end
end

function command.killBoss(bossId)
    for _, room in pairs(rooms) do
        bosses[bossId] = nil
        room:killBoss(bossId)
    end
end
----------------------------------------------------

local function update()
    local now = skynet.now()
    local dt = (now - prevUpdateTime) / 100
    prevUpdateTime = now
    skynet.timeout(TICK_INTERVAL, update)
    for roomId, room in pairs(rooms) do
        room:update(dt)
        if room:isOver() then
            for roleId, playerInfo in pairs(room:getPlayers()) do
                if playerInfo.state ~= PlayerState.GIVE_UP then
                    roles[roleId] = nil
                    joinArenas[roleId] = nil
                end
            end

            local arena = arenaList[roomId]
            local joinInfo = {}
            joinInfo.roomId = roomId
            joinInfo.type = arena.type
            joinInfo.level = arena.level
            joinInfo.password = arena.password
            joinInfo.isBegan = arena.isBegan
            context.castS2C(nil, M_CatchFish.handleJoinArenaInfoUpdate, joinInfo)

            rooms[roomId] = nil
            arenaList[roomId] = nil
            room:destroy()
            roomCount = roomCount - 1
            -- logger.Pf("svc:%d, destroy, roomCount:%d", skynet.self(), roomCount)
        end
    end
end

function command.setSetting(type, value)
    settings[type] = value

    for _, room in pairs(rooms) do
        if type == "protect" then --新手保护
            room:setProtect(settings["protect"])
        end
    end
end

function command.getSetting(type, value)
    return settings[type]
end

function command.getAllSettings()
    return settings
end

function command.getCathFishSvcInfo()
    return {robotNum = CatchFishRobotMgr.getRobtoNum(), roomNum = table.nums(rooms)}
end

function command.getRobtoNum()
    return CatchFishRobotMgr.getRobtoNum()
end

local configs = require("config.cache")
local function initConfig()
    configDb = require("config.config_db")
    configDb.init(configs)
end

function command.dispatchNormalRoom()
    skynet.timeout(UPDATE_ROOM_INTERVAL * 100, command.dispatchNormalRoom)
    if not command.isInit() then return end

    -- 获得只有机器人的房间
    local robotRoomIndex = {}
    for roomId, room in pairs(rooms) do
        if room:getRobotNum() == table.nums(room._players) then
            table.insert(robotRoomIndex, roomId)
        end
    end

    -- 多余的房间删除
    while #robotRoomIndex > NORMAL_ROOM_NUM do
        local roomId = table.remove(robotRoomIndex, 1)
        local room = rooms[roomId]
        for roleId,playerInfo in pairs(room._players or {}) do
            command.leave(roleId)
        end
    end

    -- 房间不足，则创建房间
    while #robotRoomIndex < NORMAL_ROOM_NUM do
        local room = getEmptyRoom()
        table.insert(robotRoomIndex, room:getRoomId())
        local randmon = math.rand(100)
        if randmon < 20 then 
            room.robotMaxNum = 1
        elseif 20 <= randmon and randmon < 40 then
            room.robotMaxNum = 3
        else
            room.robotMaxNum = 2
        end 
        command.addRobotToRoom(room)
    end
end


function command.addRobotToRoom(room, lgnoreTime, screening, replace)
    if not room:hasEmptyPos() then return end

    if not lgnoreTime then 
        if room._nextRobotJoinTimeAt and room._nextRobotJoinTimeAt > skynet.time() then
            return
        end
    end

    local RobotInfo = CatchFishRobotMgr.getRobot(screening, replace)
    if not RobotInfo then return end
    
    RobotInfo.roomId = room:getRoomId()
    RobotInfo.exitAt = skynet.time() + RobotInfo.exitTime
    local ret = command.enter(RobotInfo)
    if ret == SystemError.success then
        CatchFishRobotMgr.setRobotRoom(RobotInfo.roleId, room:getRoomId())
    end
end

local function createRobotVipRoom(minGunLevel, pwd)
    local RobotInfo = CatchFishRobotMgr.getRobot({minGunLevel = minGunLevel})
    if not RobotInfo then return end

    RobotInfo.exitAt = skynet.time() + RobotInfo.exitTime
    RobotInfo.password = pwd or ""
    RobotInfo.minGunLevel = CatchFishRobotMgr.getNearLevel(RobotInfo.gunLevel, {10,100,200,500,1000,2000,5000}, "<=")
    local ret,roomInfo = command.createVip(RobotInfo)
    if ret ~= SystemError.success or not roomInfo or not roomInfo.roomId then return end
    local room = rooms[roomInfo.roomId]
    if not room then return end
    CatchFishRobotMgr.setRobotRoom(RobotInfo.roleId, roomInfo.roomId)
    
    room.robotMaxNum = 3
    if math.rand(100) % 3 < 1 then 
        room.robotMaxNum = 4
    end 
end

function command.addRobotToVipRoom(room, pwd, minGunLevel)
    local RobotInfo = CatchFishRobotMgr.getRobot({minGunLevel = minGunLevel})
    if not RobotInfo then return end

    RobotInfo.exitAt = skynet.time() + RobotInfo.exitTime

    if not room:hasEmptyPos() then return end
    if room._nextRobotJoinTimeAt and room._nextRobotJoinTimeAt > skynet.time() then return end
    RobotInfo.roomId = room:getRoomId()
    RobotInfo.password = room:getPassword()
    
    -- 真实玩家创建的密码房，机器人不能进入
    if RobotInfo.password and RobotInfo.password ~= "" and RobotInfo.password ~= "robot001" then 
        return
    end 
    local ret = command.enter(RobotInfo)
    if ret == SystemError.success then
        CatchFishRobotMgr.setRobotRoom(RobotInfo.roleId, room:getRoomId())
    end
end

function command.dispatchVIPRoom()
    skynet.timeout(UPDATE_ROOM_INTERVAL * 100, command.dispatchVIPRoom)
    if not command.isInit() then return end

    -- 时间段不同，VIP 房间数不同
    local realVIP_ROOM_NUM = VIP_ROOM_NUM
    local realPWD_ROOM_NUM = PWD_ROOM_NUM
    local timeData = {
        year=os.date("%Y"),
        month=os.date("%m"),
        day=os.date("%d"), 
        hour=0, 
        min=0, 
        sec=0
    }
    for _,timeInfo in pairs(PEAK_TIME_LIST) do
        timeData.hour = timeInfo[1][1]
        timeData.min = timeInfo[1][2]
        local beginTime = os.time(timeData)
        timeData.hour = timeInfo[2][1]
        timeData.min = timeInfo[2][2]
        local endTime = os.time(timeData)
        local now = skynet.time()
        if beginTime <= now and now <= endTime then
            realVIP_ROOM_NUM = timeInfo[3][1]
            realPWD_ROOM_NUM = timeInfo[3][2]
            break
        end
    end

    if math.rand(10000) % 2 >= 1 then
        realVIP_ROOM_NUM = realVIP_ROOM_NUM + 1
        realPWD_ROOM_NUM = realPWD_ROOM_NUM + 1
    end

    -- print("realVIP_ROOM_NUM:"..realVIP_ROOM_NUM.." realPWD_ROOM_NUM:"..realPWD_ROOM_NUM.." #rooms:"..table.nums(rooms))

    -- 纯机器人房间大于指定数值时，退出房间
    local roomNum = 0
    local pwdRoomNum = 0
    for roomId, room in pairs(rooms) do
        local flag = false
        -- 纯机器人的房间
        if room:isVip() and room:getPlayerNum() == 0 then
            if roomNum > realVIP_ROOM_NUM or pwdRoomNum > realPWD_ROOM_NUM then
                flag = true
            else
                if room:needPassword() then
                    pwdRoomNum = pwdRoomNum + 1
                else
                    roomNum = roomNum + 1
                end
            end
        end

        if flag then
            for roleId,playerInfo in pairs(room._players or {}) do
                command.leave(roleId)
            end
        end
    end

    -- 创建无密码房间
    while roomNum < realVIP_ROOM_NUM do
        roomNum = roomNum + 1
        createRobotVipRoom(500)
    end

    -- 创建有密码房间
    breakWhile = 0
    while pwdRoomNum < realPWD_ROOM_NUM do
        pwdRoomNum = pwdRoomNum + 1
        createRobotVipRoom(500, "robot001")
    end
end

function command.dispatchAddRobot()
    skynet.timeout(4 * 100, command.dispatchAddRobot)

    for roomId, room in pairs(rooms) do
        local robotNum = room:getRobotNum()
        local robotMaxNum = room.robotMaxNum or 2
        if robotNum < robotMaxNum and math.rand(100) % 3 < 1 then
            if roomType == RoomType.NORMAL then
                command.addRobotToRoom(room)
            elseif roomType == RoomType.VIP then
                command.addRobotToVipRoom(room)
            end
        end
    end    
end 

function command.dispatchLeavingRobot()
    skynet.timeout(5 * 100, command.dispatchLeavingRobot)
    
    local now = skynet.time()
    for roomId, room in pairs(rooms) do
        -- 机器人离开
        for roleId,playerInfo in pairs(room._players or {}) do
            if playerInfo.isRobot then
                if playerInfo.leavingAt and playerInfo.leavingAt < now then 
                    command.leave(roleId)
                elseif playerInfo.exitAt and playerInfo.exitAt < now then
                    command.leave(roleId)
                end
            end
        end
    end
end 

function command.dispatchRobot()
    skynet.timeout(FIRE_INTERVAL * 100, command.dispatchRobot)
    if not command.isInit() then return end
    for roomId, room in pairs(rooms) do
        room:updateRobot() 
    end
end

skynet.start(function()
    -- 初始化配置
    initConfig()

    prevUpdateTime = skynet.now()
    skynet.timeout(TICK_INTERVAL, update)
end)

return command