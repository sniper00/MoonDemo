local json = require("json")

local get_env = _G.get_env
local set_env = _G.set_env
local new_service = _G.new_service

-- define lua module search dir
local path = "moon/lualib/?.lua;lualib/?.lua;game/?.lua;"

-- define lua c module search dir
local cpath = "moon/clib/?.dll;moon/clib/?.so;tools/?.lua;"

package.path = path .. package.path
package.cpath = cpath .. package.cpath

set_env("PATH", path)
set_env("CPATH", cpath)

local params = json.decode(get_env("PARAMS"))

local services ={
    {
        unique = true,
        name = "login",
        file = "game/login.lua",
        host = params.host,
        port = params.login_port,
        count = 4,
        master = true
    },
    {
        unique = true,
        name = "gate",
        file = "game/gate.lua",
        host =  params.host,
        port = params.gate_port
    },
    {
        unique = true,
        name = "center",
        file = "game/center.lua",
        max_room_player_number = params.max_room_player_number,
        time = params.round_time
    },
    {
        name = "robot",
        file = "robot/robot.lua",
        unique = true,
        host = "127.0.0.1",
        port = params.gate_port,
        login_port = params.login_port,
        num = params.robot_num
    }
}

for _, conf in ipairs(services) do
    local service_type = conf.service_type or "lua"
    local unique = conf.unique or false
    local threadid = conf.threadid or 0

    new_service(service_type, json.encode(conf), unique, threadid, 0 ,0 )
end

return #services