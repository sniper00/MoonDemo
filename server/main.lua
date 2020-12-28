-- Define lua module search dir, all services use same lua search path
local path = table.concat({
    "moon/lualib/?.lua",
    "moon/service/?.lua",
    "game/?.lua"
    -- Append your lua module search path
},";")

package.path = path .. package.path

local moon = require("moon")
local json = require("json")

moon.set_env("PATH", string.format("package.path='%s'..package.path", path))

local params = json.decode(moon.get_env("PARAMS"))

local services ={
    {
        unique = true,
        name = "db_openid",
        file = "moon/service/redisd.lua",
        threadid = 1,
        poolsize = 5,
        host = "127.0.0.1",
        port = 6379,
        timeout = 1000,
    },
    {
        unique = true,
        name = "db_server",
        file = "moon/service/redisd.lua",
        threadid = 1,
        host = "127.0.0.1",
        port = 6379,
        timeout = 1000,
    },
    {
        unique = true,
        name = "db_user",
        file = "moon/service/redisd.lua",
        threadid = 1,
        poolsize = 5,
        host = "127.0.0.1",
        port = 6379,
        timeout = 1000,
    },
    {
        unique = true,
        name = "auth",
        file = "game/auth.lua",
        threadid = 2,
    },
    {
        unique = true,
        name = "gate",
        file = "game/gate.lua",
        host =  params.host,
        port = params.port,
        threadid = 3,
    },
    {
        unique = true,
        name = "center",
        file = "game/center.lua",
        max_room_player_number = params.max_room_player_number,
        round_time = params.round_time,
        threadid = 4,
    },
    {
        name = "robot",
        file = "robot/robot.lua",
        unique = true,
        host = "127.0.0.1",
        port = params.port,
        num = params.robot_num
    }
}

local function Start()
    ---控制服务初始化顺序,Init一般为加载DB
    assert(moon.co_call("lua", moon.queryservice("auth"), "Init"))
    assert(moon.co_call("lua", moon.queryservice("center"), "Init"))
    assert(moon.co_call("lua", moon.queryservice("gate"), "Init"))

    ---加载完数据后 gate 才开始接受客户端连接
    assert(moon.co_call("lua", moon.queryservice("gate"), "Start"))
end

local server_ok = true
local addrs = {}

moon.async(function()
    for _, conf in ipairs(services) do
        local service_type = conf.service_type or "lua"
        local unique = conf.unique or false
        local threadid = conf.threadid or 0
        local addr = moon.new_service(service_type, conf, unique, threadid)
        ---如果关键服务创建失败，立刻退出进程
        if 0 == addr then
            server_ok = false
            moon.exit(-100)
            return
        end
        table.insert(addrs, addr)
    end

    local ok, err = xpcall(Start, debug.traceback)
    if not ok then
        moon.error("server will abort, init error\n", err)
        server_ok = false
        moon.exit(-100)
        return
    end

end)

---注册进程退出信号处理
moon.shutdown(function()
    print("receive shutdown")
    moon.async(function()
        if server_ok then
            print(moon.co_call("lua", moon.queryservice("gate"), "Shutdown"))
            print(moon.co_call("lua", moon.queryservice("center"), "Shutdown"))
            print(moon.co_call("lua", moon.queryservice("auth"), "Shutdown"))

            moon.send("system", moon.queryservice("db_server"), "wait_save")
            moon.send("system", moon.queryservice("db_user"), "wait_save")
            moon.send("system", moon.queryservice("db_openid"), "wait_save")

            moon.remove_service(moon.queryservice("robot"))
        else
            local auth = moon.queryservice("auth")
            ---some user may loaded
            if auth >0 then
                moon.co_call("lua", auth, "RemoveAllUser")
            end
            for _, addr in ipairs(addrs) do
                moon.remove_service(addr)
            end
        end
        moon.quit()
    end)
end)