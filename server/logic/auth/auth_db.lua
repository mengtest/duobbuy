local skynet = require("skynet")
local context = require("common.context")
local globalConf = require("config.global")
local gunConf = require("config.gun")
local noviceConfig = require("config.novice_protection")
local roleConst = require("role.role_const")
local noviceConst = roleConst.novices

local createRoleCmds = require("auth.create_role_cmds")

local authDb = {}

function authDb.getRole(db, uid)
	local ret = db.Role:findOne({uid = uid}, {_id = 1, loginIP = 1, chargeNum = 1})
    local role = {}
    if ret then
        role.roleId = ret._id
        role.loginIP = ret.loginIP
        role.chargeNum = ret.chargeNum
    end
	return role
end

function authDb.getRoleIdByNickname(db, nickname)
	local ret = db.Role:findOne({nickname = nickname}, {_id = 1})
	return ret and ret._id
end

--创建角色
function authDb.createRole(db, data)
	data._id = context.callS2S(SERVICE.MAIN_DB, "getAutoIncrId", "Role")
	data.createTime = skynet.time()
    if not data._id then
        return nil
    end
    data.roleId = data._id
    data.nickname = data.nickname or table.concat({"拓荒者", data._id})
    data.gold = globalConf.ROLE_INIT_GOLD
    data.gun = globalConf.ROLE_INIT_GUN
    data.notFishGold = globalConf.ROLE_INIT_NOVICE
    data.guns = {globalConf.ROLE_INIT_GUN}
    data.gunLevel = gunConf[globalConf.ROLE_INIT_GUN].minLevel
    data.treasure = globalConf.ROLE_INIT_TREASURE
    data.isVip = false
    data.chargeStatus = false
    data.loginIP = data.ip

    if noviceConst.reg and noviceConfig[noviceConst.reg] then
        data.novice = noviceConfig[noviceConst.reg].num
    end

    for _, cmd in ipairs(createRoleCmds) do
        cmd(db, data._id)
    end
    db.Role:safe_insert(data)

    if data.imei and #data.imei > 5 then
        db.DeviceRole:update(
                {imei = data.imei},
                {["$inc"] = {["count"] = 1}},
                true
            )
    end

	return data._id
end

function authDb.getRoleInfo(db, roleId)
    local ret = db.Role:findOne({_id = roleId})
    if not ret then
        return
    end
    ret.roleId = roleId

    if ret.imei and #ret.imei > 5 then
        local deviceRole = db.DeviceRole:findOne({imei = ret.imei})
        if deviceRole and deviceRole.count > 1 then
            ret.deviceRoleCount = deviceRole.count
            ret.deviceNotFishGold = 0
            ret.deviceGold = 0
            ret.deviceFishTreasure = 0
            -- local roles = db.Role:find(
            --         {imei = ret.imei},
            --         {_id=false,notFishGold=true,gold=true,fishTreasure=true}
            --     ):sort({createTime=-1}):limit(5)
            -- while roles:hasNext() do
            --     local r = roles:next()
            --     ret.deviceNotFishGold = ret.deviceNotFishGold + (r.notFishGold or 0)
            --     ret.deviceGold = ret.deviceGold + r.gold
            --     ret.deviceFishTreasure = ret.deviceFishTreasure + (r.fishTreasure or 0)
            -- end
        end
    end
    return ret
end


function authDb.changeName(db, roleId, newNickName, newchangeNameCount)
    return db.Role:update(
        { ["_id"] = roleId},
        { ["$set"] = { ["nickname"] = newNickName} }
    )
end

function authDb.setLastLoginTime(db, roleId, loginTime)
    db.Role:update(
        {_id = roleId},
        {["$set"] = {["loginTime"] = loginTime}}
    )
end

function authDb.setLastLogoutInfo(db, roleId, logoutInfo)
    local doc = {
        query = {_id = roleId},
        update = {["$set"] = logoutInfo},
        upsert = true,
    }
    db.Role:findAndModify(doc)
end

function authDb.addRobot(db, nickname)
    local data = {
        nickname = nickname,
    }
    db.Robot:insert(data)
end

function authDb.getRobotByNickname(db, nickname)
    local ret = db.Robot:findOne({nickname = nickname}, {_id = 1})
    return ret and ret._id
end

function authDb.checkRoleIsExist(db, roleId)
    local ret = db.Role:findOne({_id = roleId}, {_id = 1})
    return ret and ret._id
end

function authDb.getWhiteDevices(db)
    local rets = db.WhiteDevice:find({}, {imei = 1})
    local imeis = {}
    while rets:hasNext() do
        local result = rets:next()
        imeis[result.imei] = true
    end
    return imeis
end

function authDb.setForbidIP(db, ip, endTime)
    local data = {
        query = {_id = ip},
        update = {["$set"] = {endTime = endTime}},
        upsert = true,
    }
    db.ForbidIP:findAndModify(data)
end

function authDb.getForbidIPEndTime(db, ip)
    local ret = db.ForbidIP:findOne({ip = ip}, {endTime = 1})
    return ret and ret.endTime or 0
end

function authDb.getLoginUserCountByIP(db, ip, startTime, limit)
    return db.Role:find({loginIP = ip, loginTime = {["$gt"] = startTime}}):limit(limit):count()
end

function authDb.getLoginIp(db, startTime)
    local loginIpList = {}
    local AllRole = db.Role:find({})
    while AllRole:hasNext() do
		local info = AllRole:next()
        if info.ip and info.loginTime and info.loginTime > startTime then 
            if not loginIpList[info.ip] then 
                loginIpList[info.ip] = {}
            end
            loginIpList[info.ip][info.uid] = info.loginTime
        end
	end
    return loginIpList
end

function authDb.getAllNickName(db)
    local nickNameIndex = {}
    local AllRole = db.Role:find({})
    while AllRole:hasNext() do
		local info = AllRole:next()
        nickNameIndex[info.nickname] = true
	end
    return nickNameIndex
end

return authDb