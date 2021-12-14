local json = require("json")
local seri = require("seri")
local buffer = require("buffer")
local code = require("common.cmdcode")

local jdecode = json.decode
local concats = seri.concats
local type = type

local bsize = buffer.size
local bsubstr = buffer.substr

-- used for find message name by id
local id_name = {}
-- used for id bytes cache
local id_bytes = {}

for k,v in pairs(code) do
    local c = string.pack("<H",v)

    assert(not id_name[c],"")
    id_name[c] = k

    assert(not id_bytes[v],"")
    id_bytes[v] = c
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
    local name = id_name[bsubstr(buf, 0, 2)]
    if size > 2 then
        return name, jdecode(bsubstr(buf, 2, -1))
    end
    return name
end

function M.bytes_to_name(bytes)
    return id_name[bytes]
end

return M