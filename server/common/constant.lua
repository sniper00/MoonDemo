local moon = require("moon")
local M = {
    PTYPE = {
        CLIENT = 100,
        TO_CLIENT = 101,
    },
    Type = {
        Player = 1,
        Food = 2
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
