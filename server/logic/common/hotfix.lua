local Hotfix = {}

--[[
    获取函数的upvalue
    @param f 函数
    @param upname upvalue的变量名
    @result 返回指定的upvalue
]]
function Hotfix.getupvalue(f, upname)
   local i = 1
	while true do
		local name, value = debug.getupvalue(f, i)
		if name == nil then
			break
		end
      if name == upname then
        return value, i
      end
		i = i + 1
	end
end

--[[
    修改upvalue为新的值,其他函数引用到同一个upvalue的都会改变
    @param f 函数
    @param upname upvalue的变量名
    @value 新的值
]]
function Hotfix.setupvalue(f, upname , value )
    local key
    local set = function( v ) key = v  end
    Hotfix.linkupvalue( f, upname , set , "key" )
    set(value)
end

--[[
    把旧函数的upvalue关联到新函数
    @param f 旧函数
    @param new_f 新函数
    @param upname upvalue的变量名
]]
function Hotfix.linkupvalue( f, upname , new_f ,newname )
   newname = newname or upname
   local _, newId = Hotfix.getupvalue(new_f, newname)
   local _, oldId = Hotfix.getupvalue(f, upname)
   if newId and oldId then
        debug.upvaluejoin(new_f, newId, f, oldId)
   end
end

--[[
    获取文件的代码块
    @param filename 文件路径
    @result 返回文件的chunk
]]
function Hotfix.getChunk(filename)
    local f = io.open(filename, "rb")
    if not f then
        print("can not open file")
        return
    end
    
    local source = f:read "*a"
    f:close()
    
    return source
end

return Hotfix