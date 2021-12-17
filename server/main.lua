---__init__
if _G["__init__"] then
    local arg = ...
    return {
        thread = 8,
        enable_console = true,
        logfile = string.format("log/game-%s-%s.log", arg[1], os.date("%Y-%m-%d-%H-%M-%S")),
        loglevel = "DEBUG",
    }
end

-- Define lua module search dir, all services use same lua search path
local path = table.concat({
    "./?.lua",
    "moon/lualib/?.lua",
    "moon/service/?.lua",
    "game/?.lua"
    -- Append your lua module search path
},";")

package.path = path .. ";"

local moon = require("moon")
moon.set_env("PATH", string.format("package.path='%s'", package.path))

local arg = load(moon.get_env("ARG"))()

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
        file = "game/service_auth.lua",
        threadid = 2,
    },
    {
        unique = true,
        name = "gate",
        file = "game/service_gate.lua",
        host =  "0.0.0.0",
        port = 12345,
        threadid = 3,
    },
    {
        unique = true,
        name = "center",
        file = "game/service_center.lua",
        max_room_player_number = 100,--匹配人数达到100就创建房间
        round_time = 60,--每局持续60s
        threadid = 4,
    },
    {
        name = "robot",
        file = "robot/robot.lua",
        unique = true,
        host = "127.0.0.1",
        port = 12345,
        num = 99--登录99个机器人，留下一个用unity登录
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
        local addr = moon.new_service("lua", conf)
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
            assert(moon.co_call("lua", moon.queryservice("gate"), "Gate.Shutdown"))
            assert(moon.co_call("lua", moon.queryservice("center"), "Center.Shutdown"))
            assert(moon.co_call("lua", moon.queryservice("auth"), "Auth.Shutdown"))
            moon.sleep(5000)
            moon.raw_send("system", moon.queryservice("db_server"), "wait_save")
            moon.raw_send("system", moon.queryservice("db_user"), "wait_save")
            moon.raw_send("system", moon.queryservice("db_openid"), "wait_save")

            moon.remove_service(moon.queryservice("robot"))
        else
            moon.exit(-1)
        end

        ---wait all service quit
        while true do
            local size = moon.size()
            if size == 1 then
                break
            end
            moon.sleep(200)
            print("bootstrap wait all service quit, now count:", size)
        end

        moon.quit()
    end)
end)