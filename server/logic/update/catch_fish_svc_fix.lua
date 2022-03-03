local hotfix = require("common.hotfix")
local context = require("common.context")
local skynet = require("skynet")
local dbHelp = require("common.db_help")
local resOp = require("common.res_operate")
local logger = require("log")



local Room = require("catch_fish.room")
local command =  require("command_base")
local rooms = hotfix.getupvalue(command.leave, "rooms")
local sendMarquee = hotfix.getupvalue(command.createVip, "sendMarquee")
local settings = hotfix.getupvalue(command.createVip, "settings")
local roomCount = hotfix.getupvalue(command.joinArena, "roomCount")
local nextRoomId = 0

local function getRobotRoom1()
    for _, room in pairs(rooms) do
		print("room:getPlayerNum():"..room:getPlayerNum())
        if room:hasEmptyPos() and room:getPlayerNum() < 1 then
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
	print("nextRoomId:"..nextRoomId)

    room:bornBosses(bosses, false)

    roomCount = roomCount + 1

    return room
end

local CatchFishConst = require("catch_fish.catch_fish_const")
local RoomType = CatchFishConst.RoomType
local roles = hotfix.getupvalue(command.enter, "roles")

function command.enter(enterInfo)
    local room
    if enterInfo.roomId then
        room = rooms[enterInfo.roomId]
        if roomType == RoomType.VIP then
            command.leave(enterInfo.roleId)
        end
    else
        -- room = getRoom()
        room = getRobotRoom1()
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




-- local personal_benefit = {}

-- local private_benefit = require("config.private_benefit1")

-- for _, item in ipairs(private_benefit) do
-- 	local items = personal_benefit[item.group]
-- 	if not items then
-- 		items = {}
-- 		personal_benefit[item.group] = items
-- 	end
-- 	items[#items + 1] = item
-- end

-- local PersonalBenefit = personal_benefit

-- function Room:_getPB(playerInfo, fish)
-- 	local pb = 1

-- 	local items = PersonalBenefit[fish:getBenefitGroup()]
-- 	if not items then
-- 		return pb
-- 	end
	
-- 	local novice = 0
-- 	if self:isProtect() then
-- 		novice = playerInfo.novice
-- 	end
-- 	local scale = (novice + playerInfo.notFishGold) / (math.max(1, playerInfo.gold) / EXPECTED_GET_TREASURE_RATIO + playerInfo.fishTreasure)
-- 	local index = math.min(#items, table.lowerBound(items, scale, "scale"))
-- 	local conf = items[index]
-- 	if conf then
-- 		pb = conf.rate / 10000
-- 	end
-- 	return pb
-- end


-- local RoomType = CatchFishConst.RoomType
-- local roles = hotfix.getupvalue(command.hit, "roles")
-- local PUMP_RATIO = 0.25
-- local bossAp = 1
-- function command.hit(hitInfo)
--     local room = roles[hitInfo.roleId]
--     if not room then
--         if roomType == RoomType.ARENA then
--             return CatchFishError.arenaIsOver
--         else
--             return SystemError.illegalOperation
--         end
--     end
--     hitInfo.pumpRatio = -PUMP_RATIO
--     hitInfo.bossAp = bossAp
--     return room:hit(hitInfo)
-- end

-- function Room:_doHit(playerInfo, hitInfo)
-- 	local hitFish
-- 	local costNotFishGold = 0
-- 	local bullets = playerInfo.bullets
-- 	local catchFishes = {}
-- 	for _, hit in ipairs(hitInfo.hits) do
-- 		local bullet = bullets[hit.bulletId]
-- 		if bullet then
-- 			bullets[hit.bulletId] = nil
-- 			local fish = self._fishes[hit.fishId]
-- 			if fish then
-- 				hitFish = fish

-- 				if fish:isBoss() then
-- 					costNotFishGold = costNotFishGold + bullet:getLevel()
-- 				end

-- 				local extraRatio = 1
-- 				if playerInfo.isCrit then
-- 					extraRatio = extraRatio + 0.2
-- 				end

-- 				if bullet:getType() == CatchFishConst.CHENG_JIE then
-- 					self:_doChengJieGun(playerInfo, hit, bullet, hitInfo.pumpRatio, catchFishes)
-- 				else
-- 					local catch, crit = self:_checkCatch(playerInfo, fish, bullet, hitInfo.pumpRatio, extraRatio)
-- 					if catch then
-- 						self._fishes[hit.fishId] = nil
-- 						catchFishes[#catchFishes + 1] = {fish, bullet, crit}
-- 						self:_checkSendMarquee(playerInfo, fish)
-- 						local fishIds = self:_getCaughtFishes(fish)
-- 						local fishTypes = {}
-- 						if fishIds then
-- 							for _, fishId in ipairs(fishIds) do
-- 								local f = self._fishes[fishId]
-- 								self._fishes[fishId] = nil
-- 								catchFishes[#catchFishes + 1] = {f, bullet, 1}
-- 								fishTypes[#fishTypes+1] = f:getType()
-- 							end
-- 						end
-- 						if fish:getType() == FishType.GLOBAL_BOMB
-- 							or fish:getType() == FishType.LOCAL_BOMB then
-- 							logger.Pf("roleId:%d,bulletLevel:%d,type:%d,fishTypes:%s"
-- 								, playerInfo.roleId, bullet:getLevel(), fish:getType(), table.concat(fishTypes, ","))
-- 						end
-- 					end
-- 					if bullet:getType() == CatchFishConst.JI_GUANG_GUN and math.rand(0, 1) <= HIT_EXTRA_RATIO then
-- 						self:_doJiguangGun(playerInfo, hit, bullet, hitInfo.pumpRatio, catchFishes)
-- 					end
-- 				end
-- 			end
-- 		end
-- 	end
-- 	return hitFish, catchFishes, costNotFishGold
-- end


-- function Room:_checkCatch(playerInfo, fish, bullet, pumpRatio, extraRatio)
-- 	if not fish or fish:isDead() or not fish:isBorned() then
-- 		return false
-- 	end

-- 	local dropGold = fish:getGoldDrop() * bullet:getLevel()

-- 	if playerInfo.isVip == false and playerInfo.gold < self._maxGoldOfFreePlayer then
-- 		if dropGold + playerInfo.gold > self._maxGoldOfFreePlayer then
-- 			return false
-- 		end
-- 	end

-- 	if playerInfo.isVip then
-- 		local maxRatio
-- 		local recharge = playerInfo.notFishGold / 5500

-- 		if recharge <= 200 then
-- 			maxRatio = math.max(1.36, -1.48 * math.log(recharge) + 11.578)
-- 		else
-- 			maxRatio = math.max(1.36, 33.91 * (recharge ^ -0.449))
-- 		end

-- 		if playerInfo.deviceRoleCount > 10 and playerInfo.deviceRoleCount < 500 then
-- 			maxRatio = 1
-- 		elseif playerInfo.deviceRoleCount >= 500 then
-- 			maxRatio = 0.4
-- 		end
		
-- 		if playerInfo.gold + playerInfo.fishTreasure * EXPECTED_GET_TREASURE_RATIO
-- 	    	 < playerInfo.notFishGold * maxRatio then
-- 			if (playerInfo.gold + dropGold) + playerInfo.fishTreasure * EXPECTED_GET_TREASURE_RATIO
-- 				 >= playerInfo.notFishGold * maxRatio then
-- 				return false
-- 			end
-- 	    end
-- 	end

--     extraRatio = extraRatio or 1

--     local crit
--     if bullet:getType() == CatchFishConst.SHUANG_SHENG_ZHI_LI then
--     	local fishDrop = fish:getGoldDrop()
--     	if fishDrop < 10 then
--     		extraRatio  = extraRatio * 0.9091
--     		crit = math.rand() <= 0.1
--     	elseif fishDrop >= 10 and fishDrop < 50 then
--     		extraRatio  = extraRatio * 0.8333
--     		crit = math.rand() <= 0.2
--     	elseif fishDrop >= 50 and fishDrop < 100 then
--     		extraRatio  = extraRatio * 0.7692
--     		crit = math.rand() <= 0.3
--     	end
-- 	end

-- 	crit = crit and 2 or 1

-- 	if bullet:getType() == CatchFishConst.JIE_NENG then
-- 		extraRatio  = extraRatio * 0.96
-- 	end
	
-- 	local CP = bullet:getCP()
-- 	local TP = pumpRatio
-- 	local PB = self:_getPB(playerInfo, fish)
-- 	local ratio = fish:getNormalRatio() * (1 + TP) * (1 + CP) * PB * extraRatio
-- 	return math.rand() <= ratio, crit
-- end

-- function Room:_doJiguangGun(playerInfo, hit, bullet, pumpRatio, catchFishes)
-- 	hit.bulletType = bullet:getType()
-- 	hit.extraFishes = {}
-- 	local count = math.rand(2, 5)
-- 	local total = table.nums(self._fishes)
-- 	local extraFishes = {}
-- 	for i = 1, count do
-- 		if total <= 0 then
-- 			break
-- 		end
-- 		local index = math.rand(1, total)
-- 		for fishId, fish in pairs(self._fishes) do
-- 			index = index - 1
-- 			if index == 0 then
-- 				extraFishes[#extraFishes + 1] = fish
-- 				self._fishes[fishId] = nil
-- 				hit.extraFishes[#hit.extraFishes + 1] = fishId
-- 				break
-- 			end
-- 		end
-- 	end

-- 	for _, fish in ipairs(extraFishes) do
-- 		self._fishes[fish:getObjectId()] = fish
-- 	end
	
-- 	for _, fishId in ipairs(hit.extraFishes) do
-- 		local fish = self._fishes[fishId]
-- 		if fish and not fish:isBoss() and self:_checkCatch(playerInfo, fish, bullet, pumpRatio, 1 / count) then
-- 			self._fishes[fishId] = nil
-- 			catchFishes[#catchFishes + 1] = {fish, bullet}
-- 			self:_checkSendMarquee(playerInfo, fish)
-- 			local fishIds = self:_getCaughtFishes(fish)
-- 			local fishTypes = {}
-- 			if fishIds then
-- 				for _, fishId in ipairs(fishIds) do
-- 					local f = self._fishes[fishId]
-- 					self._fishes[fishId] = nil
-- 					catchFishes[#catchFishes + 1] = {f, bullet, 1}
-- 					fishTypes[#fishTypes+1] = f:getType()
-- 				end
-- 			end
-- 			if fish:getType() == FishType.GLOBAL_BOMB
-- 				or fish:getType() == FishType.LOCAL_BOMB then
-- 				logger.Pf("roleId:%d,bulletLevel:%d,type:%d,fishTypes:%s"
-- 					, playerInfo.roleId, bullet:getLevel(), fish:getType(), table.concat(fishTypes, ","))
-- 			end
-- 		end
-- 	end

-- 	self:_cast(M_CatchFish.handleHit, {roleId = playerInfo.roleId, hits = {hit}})
-- end

-- function Room:_doChengJieGun(playerInfo, hit, bullet, pumpRatio, catchFishes)
-- 	local hitFish = self._fishes[hit.fishId]
-- 	if hitFish then
-- 		local hitFishIds = self:_getRangeFishes(hitFish, 65)
-- 		local count = table.nums(hitFishIds)		
-- 		for _, fishId in ipairs(hitFishIds) do
-- 			local fish = self._fishes[fishId]
-- 			if fish and not fish:isBoss() and self:_checkCatch(playerInfo, fish, bullet, pumpRatio, 1 / count) then
-- 				self._fishes[fishId] = nil
-- 				catchFishes[#catchFishes + 1] = {fish, bullet}
-- 				self:_checkSendMarquee(playerInfo, fish)
-- 				local fishIds = self:_getCaughtFishes(fish)
-- 				local fishTypes = {}
-- 				if fishIds then
-- 					for _, fishId in ipairs(fishIds) do
-- 						local f = self._fishes[fishId]
-- 						self._fishes[fishId] = nil
-- 						catchFishes[#catchFishes + 1] = {f, bullet, 1}
-- 						fishTypes[#fishTypes+1] = f:getType()
-- 					end
-- 				end
-- 				if fish:getType() == FishType.GLOBAL_BOMB
-- 					or fish:getType() == FishType.LOCAL_BOMB then
-- 					logger.Pf("roleId:%d,bulletLevel:%d,type:%d,fishTypes:%s"
-- 						, playerInfo.roleId, bullet:getLevel(), fish:getType(), table.concat(fishTypes, ","))
-- 				end
-- 			end
-- 		end
-- 	end
-- end

-- local PersonalBenefit = require("config.personal_benefit")
-- function Room:_getPB(playerInfo, fish)
-- 	local pb = 1

-- 	local items = PersonalBenefit[fish:getBenefitGroup()]
-- 	if not items then
-- 		return pb
-- 	end
	
-- 	local novice = 0
-- 	if self:isProtect() then
-- 		novice = playerInfo.novice
-- 	end
-- 	local notFishGold = playerInfo.notFishGold
-- 	local scale = (novice + notFishGold) / (math.max(1, playerInfo.gold) / EXPECTED_GET_TREASURE_RATIO + (playerInfo.fishTreasure-1))
-- 	local index = math.min(#items, table.lowerBound(items, scale, "scale"))
-- 	local conf = items[index]
-- 	if conf then
-- 		pb = conf.rate / 10000
-- 	end
-- 	return pb
-- end
-- function Room:hit(hitInfo)
-- 	local playerInfo = self._players[hitInfo.roleId]
-- 	if not playerInfo then
-- 		return SystemError.argument
-- 	end

-- 	local hitFish, catchFishes, costNotFishGold = self:_doHit(playerInfo, hitInfo)

-- 	local dropTreasure = 0

-- 	if hitFish then
-- 		--达到固定消耗后获得1张夺宝卡
-- 		local subGoldIndex
-- 		if playerInfo.costGold >= GET_TREASURE_VALUES[1][1]
-- 			and playerInfo.costGold < GET_TREASURE_VALUES[2][1] then
-- 			if math.rand() < GET_TREASURE_VALUES[1][2] then
-- 				dropTreasure = 1
-- 				subGoldIndex = 1
-- 			end
-- 		elseif playerInfo.costGold >= GET_TREASURE_VALUES[2][1]
-- 			and playerInfo.costGold < GET_TREASURE_VALUES[3][1] then
-- 			if math.rand() < GET_TREASURE_VALUES[2][2] then
-- 				dropTreasure = 1
-- 				subGoldIndex = 2
-- 			end 
-- 		elseif playerInfo.costGold > GET_TREASURE_VALUES[3][1] then
-- 			dropTreasure = 1
-- 			subGoldIndex = 3
-- 		else 
-- 			--新手达到固定消耗后获得1张夺宝卡
-- 			if playerInfo.fishTreasure == 0 and playerInfo.totalCostGold >= GOT_TREASURE_GOLD_FOR_NEWBIE then
-- 				dropTreasure = 1
-- 				subGoldIndex = 0
-- 			end
-- 		end

-- 		if dropTreasure > 0 then
-- 			if subGoldIndex == 0 then
-- 				playerInfo.costGold = playerInfo.costGold - GOT_TREASURE_GOLD_FOR_NEWBIE
-- 			else
-- 				playerInfo.costGold = playerInfo.costGold - GET_TREASURE_VALUES[subGoldIndex][1]
-- 			end
-- 			self:_cast(M_CatchFish.handleDropThreasure, 
-- 				{roleId = hitInfo.roleId, fishId = hitFish:getObjectId(), treasure = dropTreasure})
-- 		end
-- 	end

-- 	playerInfo.fishTreasure = playerInfo.fishTreasure + dropTreasure
-- 	playerInfo.notFishGold = playerInfo.notFishGold - costNotFishGold

-- 	--计算捕鱼掉落
-- 	local dropGold = self:_doDropGold(hitInfo, catchFishes)

-- 	local fishes 
-- 	if not table.empty(catchFishes) then
-- 		fishes = {}
-- 		for _, item in pairs(catchFishes) do
-- 			fishes[#fishes + 1] = item[1]:getType()
-- 		end
-- 	end

-- 	return SystemError.success, {dropGold, dropTreasure, costNotFishGold, fishes}
-- end

-- local arenaList = hotfix.getupvalue(command.getArenaList, "arenaList")
-- local rooms = hotfix.getupvalue(command.joinArena, "rooms")
-- local roles = hotfix.getupvalue(command.joinArena, "roles")
-- local joinArenas = hotfix.getupvalue(command.getDoingArena, "joinArenas")

-- for roomId, arena in pairs(arenaList) do
-- 	print(",roomId", roomId)
--     for playerId, player in pairs(arena.players) do
--     	print(",playerId:", playerId)
--     	print(",pos:", player.pos)
--     	if playerId == 3085189121 and not player.pos then
--     		-- player.pos = 1
--     	end
--     end
-- end
-- joinArenas[1876332545] = nil
-- joinArenas[3085189121] = nil
-- joinArenas[1254195201] = nil
-- for roleId, arena in pairs(roles) do
-- 	print(",roleId,", roleId, ",", arena)
-- 	-- print(room.)
-- end



print("ok--------------")