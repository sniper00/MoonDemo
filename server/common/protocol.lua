local moon = require "moon"
local json = require("json")
local seri = require("seri")
local buffer = require("buffer")
local code = require("common.cmdcode")

local jdecode = json.decode
local concats = seri.concats
local type = type

local bsize = buffer.size
local bunpack = buffer.unpack

-- used for find message name by id
local id_name = {}
-- used for id bytes cache
local id_bytes = {}

for k,v in pairs(code) do
    assert(not id_name[v],"")
    id_name[v] = k

    assert(not id_bytes[v],"")
    id_bytes[v] = string.pack("<H",v)
end

local M = {}

function M.encode(id,t)
    if type(id)=='string' then
        id = code[id]
    end
    local data = id_bytes[id]
    if t then
        return concats(data,json.encode(t))
    else
        return data
    end
end

function M.decode(buf)
    local size = bsize(buf)
    if size < 2 then
        return nil
    end

    local id, p, n = bunpack(buf, "<HC")
    local name = id_name[id]
    if not name then
        error(string.format("recv unknown message code: %d.", id))
    end
    if n > 0 then
        return name, jdecode(p, n)
    end
    return name
end

function M.name(id)
    return id_name[id]
end

local pack_size_flag = 1

local ignore_print = {
    ["S2CXXX"] = true,
}

---@param uid integer
---@param m message_ptr
function M.print_message(uid, m)
    local size, buf = moon.decode(m, "NB")
    local has_pack_size = buffer.has_flag(buf, pack_size_flag)

    local offset = 0

    while true do
        local len = size
        if has_pack_size then
            len = bunpack(buf, ">H", offset)
            offset = offset + 2
        end
        local id, p, n = bunpack(buf, "<HC", offset)
        local name = id_name[id]
        offset = offset + 2
        if size > offset then
            if not ignore_print[name] then
                local t = json.decode(p, len - 2)
                moon.debug(string.format("SendTo %d Message:%s size %d \n %s", uid, name, len, json.pretty_encode(t)))
            end
            offset = offset + len - 2
        end

        if size == offset then
            break
        end
    end
end

return M