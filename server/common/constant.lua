local moon = require("moon")
local M = {
    PTYPE_C2S = 100,--- client to server
    PTYPE_S2C = 101,--- server to client
    PTYPE_SBC = 102,---server broadcast to client

    Type = {
        Player = 1,
        Food = 2
    },
    AoiEvent = {
        UpdateDir = 10,
        UpdateRadius = 11,
    }
}

local seq = 0
function M.MakeUUID(t)
    seq = seq + 1
    local times = math.tointeger(moon.get_env("SERVER_START_TIMES"))
    return (t<<24)|(times<<16)|seq
end

function M.IsPlayer(uuid)
    return (uuid>>24) == M.Type.Player
end

return M
