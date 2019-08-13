local json = require("json")
local seri = require("seri")
local code = require("common.msgcode")

local packs = seri.packs
local jdecode = json.decode
local concats = seri.concats
local type = type

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

function M.decode(msg)
    local name =  id_name[msg:substr(0,2)]
    return name, jdecode(msg:substr(2,-1))
end

return M