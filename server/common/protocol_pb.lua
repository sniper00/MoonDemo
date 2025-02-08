local moon = require "moon"
local pb = require "pb"
local json = require "json"
local buffer = require "buffer"
local seri = require "seri"
local CmdCode = require "common.CmdCode"

local concats = buffer.concat_string

local concat = buffer.concat

local pencode = pb.encode
local pdecode = pb.decode

local bunpack = buffer.unpack

local type = type

-- used for find message name by id
local id_name = {}
-- used for id bytes cache
local id_bytes = {}

for k, v in pairs(CmdCode) do
    assert(not id_name[v], "msgcode repeated")
    id_name[v] = k
    id_bytes[v] = string.pack("<H", v)
end

local M = {}

---@param uid integer
---@param id integer|string
---@param t table
---@return string
function M.encode(uid, id, t)
    if type(id) == 'string' then
        id = CmdCode[id]
    end
    local bytes = id_bytes[id]
    if t then
        local name = id_name[id]
        if not name then
            error("Unknown cmdcode: "..id)
        end
        return concat(seri.packs(uid), bytes, pencode(name, t))
    else
        return seri.packs(uid) .. bytes
    end
end

function M.encodestring(id, t)
    if type(id) == 'string' then
        id = CmdCode[id]
    end
    local bytes = id_bytes[id]
    if t then
        local name = id_name[id]
        assert(name, id)
        return concats(bytes, pencode(name, t))
    else
        return bytes
    end
end

function M.decode(buf)
    local id, p, n = bunpack(buf, "<HC")
    local name = id_name[id]
    if not name then
        error(string.format("Received unknown message CmdCode: %d. The client and server versions might not match.", id))
    end
    return name, pdecode(name, p, n)
end

function M.decodestring(data)
    local id = string.unpack("<H", data)
    local pbdata = string.sub(data, 3)
    local name = id_name[id]
    if not name then
        error(string.format("Received unknown message CmdCode: %d. The client and server versions might not match.", id))
    end
    return name, pdecode(name, pbdata), id
end

---@return string
function M.name(id)
    return id_name[id]
end

local ignore_print = {
    ["S2CXXX"] = true,
}

---@param uid integer
---@param buf buffer_ptr
function M.print_message(uid, buf)
    local size = buffer.size(buf)

    local offset = 0

    while true do
        local len = size
        local id, p, n = bunpack(buf, "<HC", offset)
        local name = id_name[id]
        offset = offset + 2
        if size >= offset then
            if not ignore_print[name] then
                local t = (size > offset) and pdecode(name, p, len - 2) or {}
                if string.sub(name, 1, 3) == "C2S" then
                    moon.debug(string.format("Recv %d Message:%s size %d \n%s", uid, name, len, json.pretty_encode(t)))
                else
                    moon.debug(string.format("SendTo %d Message:%s size %d \n%s", uid, name, len, json.pretty_encode(t)))
                end
            end
            offset = offset + len - 2
        end

        if size == offset then
            break
        end
    end
end

return M
