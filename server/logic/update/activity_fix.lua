-- telnet 127.0.0.1 5054
-- inject :04000014 ./logic/update/activity_fix.lua

local hotfix = require("common.hotfix")
local context = require("common.context")

local command =  require("command_base")

local global = require("config.global")
local dbHelp = require("common.db_help")
local md5    = require("md5")
local skynet = require("skynet")

local queue = require("skynet.queue")
local queueEnter = queue()

local initMoneyTreeInfo = hotfix.getupvalue(command.getMoneyTreeInfo, "initMoneyTreeInfo")
local resetMoneyTreeInfo = hotfix.getupvalue(command.getMoneyTreeInfo, "resetMoneyTreeInfo")

local function getMoneyTreeInfo(ret, round)
	local info = dbHelp.call("moneyTree.getInfo", round)
	if table.empty(info) then
		info = initMoneyTreeInfo(round)
	end
	local leftNum = 0
	for _,v in pairs(info) do
		leftNum = leftNum + v.num
	end

	if leftNum <= 0 then
		info, leftNum = resetMoneyTreeInfo(round)
	end
	ret.moneyTreeInfo = info
	ret.leftNum = leftNum
end

function command.getMoneyTreeInfo(round)
	local ret = {}
	queueEnter(getMoneyTreeInfo, ret, round)
	return ret
end


local initWishPoolInfo = hotfix.getupvalue(command.getWishPoolInfo, "initWishPoolInfo")
local resetWishPoolInfo = hotfix.getupvalue(command.getWishPoolInfo, "resetWishPoolInfo")

local function getWishPoolInfo(ret, round)
	local info = dbHelp.call("wishPool.getInfo", round)
	if table.empty(info) then
		info = initWishPoolInfo(round)
	end
	local leftNum = 0
	for _,v in pairs(info) do
		leftNum = leftNum + v.num
	end

	if leftNum <= 0 then
		info, leftNum = resetWishPoolInfo(round)
	end

	ret.wishWellInfo = info
	ret.leftNum = leftNum
end

function command.getWishPoolInfo(round)
	local ret = {}
	queueEnter(getWishPoolInfo, ret, round)
	return ret
end

print("activity_fix ok")