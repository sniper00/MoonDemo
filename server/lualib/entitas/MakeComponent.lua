local table_insert  = table.insert
local table_remove  = table.remove

local function com_tostring(obj)
    local lua = ""
    local t = type(obj)
    if t == "number" then
        lua = lua .. obj
    elseif t == "boolean" then
        lua = lua .. tostring(obj)
    elseif t == "string" then
        lua = lua .. string.format("%q", obj)
    elseif t == "table" then
        lua = lua .. "{"

        local first = true
        for k, v in pairs(obj) do
            if not first  then
                lua = lua .. ","
            end
            lua = lua .. com_tostring(k) .. "=" .. com_tostring(v)
            first = false
        end
        lua = lua .. "}"
    elseif t == "nil" then
        return nil
    else
        error("can not tostring" .. t .. " type.")
    end
    return lua
end

local function _replace(t, ... )
    for k, v in pairs(t._keys) do
        local n = select(k,...)
        if not n then
            return
        end
        rawset(t,v,n)
    end
end

local function _to_string( t )
    return "\t" .. t._name .. com_tostring(t)
end

local mt = {}
mt.__index = mt
mt.__tostring = function(t) return t._name end

local function make_component(name, ...)
    local tmp = {}
    tmp.__index = tmp
    tmp.__tostring = _to_string

    tmp._keys = {...}
    tmp._name = name
    tmp._is = function(t) return t._name == name end
    tmp._replace = _replace
    tmp._cache = {}
    tmp.new = function(...)
        local tb = table_remove(tmp._cache)
        if not tb then
            tb = {}
            --print("create component",name)
            setmetatable(tb, tmp)
        end
        _replace(tb,...)
        return tb
    end

    tmp.release = function(comp_value)
        assert(comp_value._name == name)
        table_insert(tmp._cache,comp_value)
    end

    setmetatable(tmp,mt)
    return tmp
end

return make_component
