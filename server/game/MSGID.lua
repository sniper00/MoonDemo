
local json = require("json")

local M = {
    MsgUnknown = 0x0000,
    C2SLogin = 0x0101,
    S2CLogin = 0x0102,
    C2SEnterRoom = 0x0301,
    C2SCommandMove = 0x0302,
    S2CEnterView = 0x0303,
    S2CLeaveView = 0x0304,
    S2CMover = 0x0305,
    S2CFood = 0x0306,
    S2CBaseData = 0x0307,
    S2CPosition = 0x0308,
    S2CDirection = 0x0309,
    S2CSpeed = 0x0310,
    S2CColor = 0x0311,
    S2CRadius = 0x0312,
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
    return table.concat({data,json.encode(t)})
end

return M