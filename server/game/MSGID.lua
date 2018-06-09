
local json = require("json")

local M = {
    MsgUnknown = 0x0000,
    C2SLogin = 0x0101,
    S2CLogin = 0x0102,
    C2SEnterRoom = 0x0301,
    S2CEnterRoom = 0x0302,
    S2CEnterViewPlayer = 0x0303,
    S2CEnterViewFood = 0x0304,
    C2SCommandMove = 0x0305,
    S2CCommandMove = 0x0306,
    S2CLeaveViewPlayer = 0x0307,
    S2CLeaveViewFood = 0x0308,
    S2CCommandMoveB = 0x0309,--玩家改变方向，广播
    S2CPlayerDead = 0x0310,
    S2CBoradcastRadius = 0x0311,
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