
local json = require("json")
local seri = require("seri")

local concats = seri.concats

local M = {
    MsgUnknown = 0x0000,
    C2SLogin = 0x0101,
    S2CLogin = 0x0102,
    CommandCreate = 0x0301,
    S2CEnterRoom = 0x0302,
    CommandMove = 0x0303,
    S2CEnterView = 0x0304,
    S2CLeaveView = 0x0305,
    Mover = 0x0306,
    Food = 0x0307,
    BaseData = 0x0308,
    Position = 0x0309,
    Direction = 0x0310,
    Speed = 0x0311,
    Color = 0x0312,
    Radius = 0x0313,
    S2CDead = 0x0314,
}

local bytes = {}

local pack = function ( id )
    local data = string.pack("<H",id)
    bytes[id] =data
    return data
end

M.encode = function (id,t)
    if type(id)=='string' then
        id = M[id]
    end
    local data = bytes[id] or pack(id)
    return concats(data,json.encode(t))
end

return M