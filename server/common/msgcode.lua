local M = {
    C2SLogin = 1,
    S2CLogin = 2,
    C2SMatch = 3,
    S2CMatch = 4,
    S2CMatchSuccess = 5,
    C2SEnterRoom = 6,
    S2CEnterRoom = 7,
    C2SMove = 8,
    S2CMove = 9,
    S2CUpdateRadius = 10,
    S2CEnterView = 11,
    S2CLeaveView = 12,
    S2CDead = 13,
    S2CGameOver = 14,
}

local forward = {
    C2SEnterRoom = "addr_room",
    C2SMove = "addr_room",
}

local mt = { forward = forward }

mt.__newindex = function(_, name, _)
    local msg = "attemp index unknown message: " .. tostring(name)
    error(debug.traceback(msg, 2))
end

mt.__index = function(_, name)
    if name == "forward" then
        return forward
    end
    local msg = "attemp index unknown message: " .. tostring(name)
    error(debug.traceback(msg, 2))
end

return setmetatable(M,mt)