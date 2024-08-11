---__init__
if _G["__init__"] then
    local arg = ...
    return {
        thread = 8,
        enable_stdout = (arg[3] ~= "hide"),
        logfile = string.format("log/hub-%s-%s.log", arg[1], os.date("%Y-%m-%d-%H-%M-%S")),
        loglevel = arg[4] or "DEBUG",
        path = table.concat({
            "./?.lua",
            "./?/init.lua",
            "game/?.lua",
            "moon/lualib/?.lua",
            "moon/service/?.lua",
            -- Append your lua module search path
        },";")
    }
end

local moon = require("moon")
local json = require"json"
local serverconf = require("serverconf")
local socket = require("moon.socket")
local common = require("common")

local GameDef = common.GameDef

local arg = moon.args()

local selfnode
local res = json.decode(io.readfile(arg[2]))
for _, v in ipairs(res) do
    if v.node == tonumber(arg[1]) then
        selfnode = v
    end
end

GameDef.LogShrinkToFit("log", selfnode.type.."-"..selfnode.node, 10)

local services = {
    {
        unique = true,
        name = "cluster",
        file = "moon/service/cluster.lua",
        threadid = 1,
        url = serverconf.CLUSTER_ETC_URL,
        etc_path = "/conf.cluster?node=%s"
    }
}

local worker_count = math.tointeger(moon.env("THREAD_NUM"))
for i=1, worker_count do
    table.insert(services, {
        name = "hub"..i,
        file = "game/service_hub.lua",
        unique = true
    })
end

moon.async(function()
    moon.env("NODE", arg[1])
    moon.env("SERVER_NAME", selfnode.type.."-"..tostring(selfnode.node))
    moon.env("NODE_FILE_NAME", arg[2])

    local workers = {}
    for _, one in ipairs(services) do
        local addr = moon.new_service(one)
        if 0 == addr then
            moon.exit(-1)
            return
        end

        if one.name:sub(1,3) == "hub" then
            moon.send("lua", addr, "loadnode")
            workers[#workers+1] = addr
        end
    end

    moon.async(function()
        local host, port = selfnode.host:match("([^:]+):?(%d*)$")
        port = math.tointeger(port) or 80

        local listenfd = socket.listen(host, port,moon.PTYPE_SOCKET_TCP)
        assert(listenfd>0)
        print("Http server start", host, port)

        local balance = 1
        while true do
            if balance>#workers then
                balance = 1
            end
            local addr = workers[balance]
            local fd = socket.accept(listenfd, addr)
            ---30(seconds) read timeout
            moon.send("lua", addr,"start", fd, 30)
            balance = balance + 1
        end
    end)
end)

moon.shutdown(function()
    moon.quit()
end)
