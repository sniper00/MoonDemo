
local json = require("json")
local seri = require("seri")

local concats = seri.concats

local M = {
    MsgUnknown = 0x0000,
    C2SLogin = 0x0101,
    S2CLogin = 0x0102,
    C2SEnterRoom = 0x0301,
    S2CEnterRoom = 0x0302,
    C2SCommandMove = 0x0303,
    S2CEnterView = 0x0304,
    S2CLeaveView = 0x0305,
    S2CMover = 0x0306,
    S2CFood = 0x0307,
    S2CBaseData = 0x0308,
    S2CPosition = 0x0309,
    S2CDirection = 0x0310,
    S2CSpeed = 0x0311,
    S2CColor = 0x0312,
    S2CRadius = 0x0313,
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