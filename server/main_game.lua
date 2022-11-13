---__init__
if _G["__init__"] then
    local arg = ...
    return {
        thread = 16,
        enable_stdout = true,
        logfile = string.format("log/game-%s-%s.log", arg[1], os.date("%Y-%m-%d-%H-%M-%S")),
        loglevel = "DEBUG",
    }
end

-- Define lua module search dir, all services use same lua search path
local path = table.concat({
    "./?.lua",
    "./?/init.lua",
    "moon/lualib/?.lua",
    "moon/service/?.lua",
    -- Append your lua module search path
}, ";")

package.path = path .. ";"

local moon = require("moon")
moon.env("PATH", string.format("package.path='%s'", package.path))

local socket = require "moon.socket"
local json = require("json")
local uuid = require("uuid")
local httpc = require("moon.http.client")
local serverconf = require("serverconf")
local common = require("common")
local GameDef = common.GameDef
local db = common.database

local arg = moon.args()

local function load_protocol(file)
    local pb = require "pb"
    local fobj = assert(io.open(file, "rb"))
    local content = fobj:read("*a")
    fobj:close()
    assert(pb.load(content))
    --- load once, then shared by other services
    pb.share_state()
end

-- If use protobuf, load *.pb file here, only need load once.
-- load_protocol("game.pb")

local function run(node_conf)
    local gate_host, gate_port = socket.parse_host_port(node_conf.host)
    local cluster_host, cluster_port = socket.parse_host_port(node_conf.cluster)

    local db_conf = serverconf.db[node_conf.node]

    local services = {
        {
            unique = true,
            name = "db_openid",
            file = "moon/service/redisd.lua",
            threadid = 1,
            poolsize = 5,
            host = db_conf.host,
            port = db_conf.port,
            timeout = db_conf.timeout,
        },
        {
            unique = true,
            name = "db_server",
            file = "moon/service/redisd.lua",
            threadid = 1,
            host = db_conf.host,
            port = db_conf.port,
            timeout = db_conf.timeout,
        },
        {
            unique = true,
            name = "db_user",
            file = "moon/service/redisd.lua",
            threadid = 1,
            poolsize = 5,
            host = db_conf.host,
            port = db_conf.port,
            timeout = db_conf.timeout,
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
            host = gate_host,
            port = gate_port,
            threadid = 3,
        },
        {
            unique = true,
            name = "center",
            file = "game/service_center.lua",
            threadid = 4,
        },
        {
            unique = true,
            name = "cluster",
            file = "moon/service/cluster.lua",
            host = cluster_host,
            port = cluster_port,
            etc_host = serverconf.NODE_ETC_HOST,
            etc_path = "/conf.cluster",
            threadid = 5,
        },
        {
            unique = true,
            name = "node",
            file = "game/service_node.lua",
            threadid = 6,
        },
        {
            unique = true,
            name = "sharetable",
            file = "moon/service/sharetable.lua",
            dir = "static/table",
            threadid = 7
        },
        {
            name = "robot",
            file = "robot/robot.lua",
            unique = true,
            host = "127.0.0.1",
            port = 12345
        }
    }

    local function Start()
        local data = db.loadserverdata(moon.queryservice("db_server"))
        if not data then
            data = {boot_times = 0}
        else
            data = json.decode(data)
        end
        ---服务器启动次数+1
        data.boot_times = data.boot_times + 1
        assert(db.saveserverdata(moon.queryservice("db_server"), json.encode(data)))
        moon.env("SERVER_START_TIMES", tostring(data.boot_times))
        ---初始化唯一ID生成器
        uuid.init(1, tonumber(arg[1]), data.boot_times)

        ---控制服务初始化顺序,Init一般为加载DB
        assert(moon.co_call("lua", moon.queryservice("auth"), "Init"))
        assert(moon.co_call("lua", moon.queryservice("center"), "Init"))
        assert(moon.co_call("lua", moon.queryservice("gate"), "Init"))
        assert(moon.co_call("lua", moon.queryservice("node"), "Init"))

        ---加载完数据后 开始接受网络连接
        assert(moon.co_call("lua", moon.queryservice("cluster"), "Start"))
        assert(moon.co_call("lua", moon.queryservice("gate"), "Start"))
    end

    local server_ok = false
    local addrs = {}

    moon.async(function()
        for _, conf in ipairs(services) do
            local addr = moon.new_service("lua", conf)
            ---如果关键服务创建失败，立刻退出进程
            if 0 == addr then
                moon.exit(-1)
                return
            end
            table.insert(addrs, addr)
        end

        local ok, err = xpcall(Start, debug.traceback)
        if not ok then
            moon.error("server will abort, init error\n", err)
            moon.exit(-1)
            return
        end
        server_ok = true
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

                moon.kill(moon.queryservice("robot"))
            else
                moon.exit(-1)
            end

            ---wait all service quit
            while true do
                local size = moon.server_stats("service.count")
                if size == 2 then
                    break
                end
                moon.sleep(200)
                print("bootstrap wait all service quit, now count:", size)
            end

            moon.kill(moon.queryservice("sharetable"))
            moon.quit()
        end)
    end)
end

moon.async(function()
    local response = httpc.get(serverconf.NODE_ETC_HOST, {
        path = "/conf.node?node=" .. tostring(arg[1])
    })

    if response.status_code ~= 200 then
        moon.error(response.status_code, response.content)
        moon.exit(-1)
        return
    end

    local node_conf = json.decode(response.content)

    moon.env("NODE", arg[1])
    moon.env("SERVER_NAME", node_conf.type.."-"..tostring(node_conf.node))
    run(node_conf)
end)
