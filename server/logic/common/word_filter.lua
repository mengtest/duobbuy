local WordFilter = {}

local MIN_PHRASE_LENGTH  = 2
local MAX_PHRASE_LENGTH = 20
local REPL = "*"
local PHRASE_SEP = "|"
local HIGHLY_SENSITIVE_LEVEL = 3

local phrasesGroup = {}

function WordFilter.init(filename)
	local file = io.open(filename, "r")
	if file == nil then 
		return false 
	end
	
	for i = 1, MAX_PHRASE_LENGTH - MIN_PHRASE_LENGTH + 1 do
		phrasesGroup[i] = {}
	end
	
	local line = file:read("*l")
	local phrases = {}
	while line do
		local ret = string.split(line, PHRASE_SEP)
		if #ret == 2 and ret[1] ~= "" and tonumber(ret[2]) ~= nil then
			phrases[ret[1]] = tonumber(ret[2])
		end
		line = file:read("*l")
	end
	
	for phrase, level in pairs(phrases) do
		local len = string.utf8len(phrase)
		if len >= MIN_PHRASE_LENGTH and len <= MAX_PHRASE_LENGTH then
			phrasesGroup[len - MIN_PHRASE_LENGTH + 1][string.lower(phrase)] = level
		end
	end
end

local function isValid(input, phrases, phraseLength)
	local offset = 0
	local len = string.utf8len(input)
	while phraseLength + offset <= len do
		local phrase = string.utf8sub(input, offset + 1, offset + phraseLength)
		phrase = string.lower(phrase)
		if phrases[phrase] then
			return false
		else
			offset = offset + 1
		end
	end
	return true
end

function WordFilter.isValid(input)
	for i = 0, MAX_PHRASE_LENGTH - MIN_PHRASE_LENGTH do
		if not isValid(input, phrasesGroup[i + 1], i + MIN_PHRASE_LENGTH) then
			return false
		end
	end
	return true
end

local function filter(input, phrases, phraseLength, highlySenLevel, repl)
	local matches = {}
	local offset = 0
	local len = string.utf8len(input)
	while phraseLength + offset <= len do
		local phrase = string.utf8sub(input, offset + 1, offset + phraseLength)
		phrase = string.lower(phrase)
		local level = phrases[phrase]
		if level and level > 0 then
			if level >= highlySenLevel then
				return 
			end
			matches[#matches + 1] = offset + 1
			matches[#matches + 1] = phraseLength
			offset = offset + phraseLength
		else
			offset = offset + 1
		end
	end
	local count = #matches / 2
	if count == 0 then
		return input
	end
	local output = ""
	local prevIndex = 1
	for i = 1, count do
		local startIndex = matches[2 * i - 1]
		local endIndex = startIndex + matches[2 * i]
		output = output .. string.utf8sub(input, prevIndex, startIndex - 1) .. string.rep(repl, matches[2 * i])
		prevIndex = endIndex
	end
	output = output .. string.utf8sub(input, prevIndex, len)
	return output
end

function WordFilter.filter(input, highlySenLevel, repl)
	repl = repl or REPL
	highlySenLevel = highlySenLevel or  HIGHLY_SENSITIVE_LEVEL
	local output = input
	local len = string.utf8len(input)
	for i = 0, MAX_PHRASE_LENGTH - MIN_PHRASE_LENGTH do
		if i + MIN_PHRASE_LENGTH > len then
			break
		end
		output = filter(output, phrasesGroup[i + 1], i + MIN_PHRASE_LENGTH, highlySenLevel, repl)
		if output == nil then
			return
		end
	end
	return output
end

return WordFilter