-- Define lua module search dir, all services use same lua search path
local path = [[moon/lualib/?.lua;moon/service/?.lua;lualib/?.lua;game/?.lua;]] -- Append your lua search path

package.path = path .. package.path

local moon = require("moon")
local json = require("json")

moon.set_env("PATH", string.format("package.path='%s'..package.path", path))

local params = json.decode(moon.get_env("PARAMS"))

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

local addrs = {}
moon.async(function()
    for _, conf in ipairs(services) do
        local service_type = conf.service_type or "lua"
        local unique = conf.unique or false
        local threadid = conf.threadid or 0
        local addr = moon.new_service(service_type, conf, unique, threadid)
        ---如果创建服务失败，立刻退出进程
        if 0 == addr then
            moon.exit(-100)
            return
        end
        table.insert(addrs, addr)
    end

    ---控制服务初始化顺序
    moon.co_call("lua", moon.queryservice("center"), "Init")
    moon.co_call("lua", moon.queryservice("gate"), "Init")

end)

---注册进程退出信号处理
moon.shutdown(function()
    moon.async(function()
        for _, addr in ipairs(addrs) do
            moon.remove_service(addr)
        end
        moon.quit()
    end)
end)