local moon = require("moon")
local queue = require("moon.queue")
local db = require("common.database")
local cmdcode = require("common.cmdcode")
local constant= require("common.constant")

local traceback = debug.traceback

local mem_player_limit = 0 --内存中最小玩家数量
local min_online_time = 60 --seconds，logout间隔大于这个时间的,并且不在线的,user服务会被退出

---@type auth_context
local context = ...

local auth_queue = {}

local function doAuth(req)
    local u = context.uid_map[req.uid]
    local addr_user
    if not u then
        local conf = {
            name = "user"..req.uid,
            file = "game/service_user.lua",
            user_db = context.user_db,
        }
        addr_user = moon.new_service("lua", conf)
        if addr_user == 0 then
            return "create user service failed!"
        end

        local ok, err = moon.co_call("lua", addr_user, "User.Load", req)
        if not ok then
            moon.send("lua", context.addr_gate, "Gate.Kick", 0, req.fd)
            moon.remove_service(addr_user)
            context.uid_map[req.uid] = nil
            return err
        end
    else
        addr_user = u.addr_user
    end

    local openid, err = moon.co_call("lua", addr_user, "User.Login", req)
    if not openid then
        moon.send("lua", context.addr_gate, "Gate.Kick", 0, req.fd)
        moon.remove_service(addr_user)
        context.uid_map[req.uid] = nil
        return err
    end

    if not u then
        u = {
            addr_user = addr_user,
            openid = openid,
            uid = req.uid,
            logouttime = moon.time(),
            online = false
        }

        context.uid_map[req.uid] = u
    end

    if req.pull then
        return
    end

    req.addr_user = addr_user

    local pass = true

    if pass then
        u.logouttime = 0
        print(req.uid, "login success")
    else
        print(req.uid, "login failed")
    end

    moon.send("lua", context.addr_gate, "Gate.BindUser", req)

    local res = {
        ok = pass,---maybe banned
        time = moon.now(),
        timezone = moon.timezone,
        uid = req.uid,
    }
    context.s2c(req.uid, cmdcode.S2CLogin, res)
end

local function QuitOneUser(u)
    moon.send("lua", u.addr_user, "User.Exit")
    context.uid_map[u.uid] = nil
end

---@class Auth
local CMD = {}

CMD.Init = function()
    context.addr_gate = moon.queryservice("gate")
    context.addr_db_openid = moon.queryservice("db_openid")
    context.addr_db_server = moon.queryservice("db_server")

    moon.async(function()
        while true do
            moon.sleep(10000)
            if context.server_exit then
                return
            end

            local now = moon.time()

            local count = table.count(context.uid_map)
            for _, u in pairs(context.uid_map) do
                if count > mem_player_limit then
                    if u.logouttime > 0 and (now - u.logouttime) > min_online_time then
                        QuitOneUser(u)
                        count = count - 1
                    end
                else
                    break
                end
            end
        end
    end)

    local res = db.loadallopenid(context.addr_db_openid) or {}
    for i=1,#res,2 do
        context.openid_map[res[i]] = math.tointeger(res[i+1])
    end

    context.start_hour_timer()

    return true
end

CMD.Start = function()
    context.start_hour_timer()
    return true
end

CMD.Shutdown = function()
    context.server_exit = true
    print("begin: server exit save user")
    local ok, err = xpcall(function()
        while true do
            local ifbreak = true
            for uid, q in pairs(auth_queue) do
                local n = q("counter")
                if n > 0 then
                    ifbreak = false
                    print("wait all async event done:", uid, n)
                    break
                end
            end
            if ifbreak then
                break
            end
            moon.sleep(100)
        end

        ---let all user service quit
        local count  = 0
        for _ ,u in pairs(context.uid_map) do
            QuitOneUser(u)
            count = count + 1
        end
        return count
    end, debug.traceback)
    print("end: server exit save user", ok, err)
    moon.quit()
    return true
end

CMD.OnHour = function(v)
    print("OnHour", v)
    for _,u in pairs(context.uid_map) do
        if u.logouttime == 0 then
            moon.send("lua", u.addr_user, "User.OnHour", v)
        end
    end
end

CMD.OnDay = function(v)
    print("OnDay", v)
    for _,u in pairs(context.uid_map) do
        if u.logouttime == 0 then
            moon.send("lua", u.addr_user, "User.OnDay", v)
        end
    end
end

---@param pull boolean @是否服务器离线加载玩家
CMD.C2SLogin = function (req, pull)
    if not req or not (req.openid or req.uid) then
        return false
    end

    pull = pull or false

    if req.openid then
        if #req.openid == 0 then
            moon.error("user auth illegal", req.fd, req.openid)
            moon.send("lua", context.addr_gate, "Gate.Kick", 0, req.fd)
            return false
        end
        ---如果是opendid, 先得到openid对应的 uid
        local uid = context.openid_map[req.openid]
        if not uid then
            uid = constant.MakeUUID(constant.Type.Player)
            db.insertuserid(context.addr_db_openid, req.openid, uid)
            context.openid_map[req.openid] = uid
        end
        req.uid = uid
    else
        req.openid = ""
        if req.uid == 0 then
            moon.error("user auth illegal", req.fd, req.uid)
            moon.send("lua", context.addr_gate, "Gate.Kick", 0, req.fd)
            return false
        end
    end

    ---服务器关闭时,中断所有客户端的登录请求
    if context.server_exit and not pull then
        return false, "auth abort"
    end

    local lock = auth_queue[req.uid]
    if not lock then
        lock = queue()
        auth_queue[req.uid] = lock
    end

    if not pull then
        if lock("count") > 0 then
            moon.error("user auth too quickly", req.fd, req.uid, req.addr, "is pull:", pull)
            moon.send("lua", context.addr_gate, "Gate.Kick", 0, req.fd)
            return
        end
        ---user may login again, but old socket not close,force close it
        ---make the user offline event in right order.
        local c = context.uid_map[req.uid]
        if c and c.logouttime==0 then
            moon.send("lua", context.addr_gate, "Kick", req.uid, 0, true)
            CMD.Disconnect(req.uid)
            return
        end
    end

    local scope_lock<close> = lock()

    if pull and context.uid_map[req.uid] then
        return true
    end

    print("user auth", req.fd, req.uid, "is pull:", pull)

    req.pull = pull

    local ok, err = xpcall(doAuth, traceback, req)
    if not ok or err then
        moon.error("CMD.C2SLogin Error", err, pull, req.uid)
        return false, err
    end
    return true
end

---加载离线玩家
local function PullUser(uid)
    local u = context.uid_map[uid]
    if not u then
        local ok,err = CMD.C2SLogin({fd =0 ,uid = uid} , true)
        if not ok then
            return ok, err
        end
        u = context.uid_map[uid]
    end
    return u
end

---向玩家发起调用，会主动加载玩家
function CMD.CallUser(uid, cmd, ...)
    if context.server_exit then
        error(string.format("call user %d cmd %s when server exit", uid, cmd))
    end

    local u, err = PullUser(uid)
    if not u then
        return false, err
    end

    if u.logouttime > 0 then
        u.logouttime = moon.time()
    end

    return moon.co_call("lua", u.addr_user, cmd, ...)
end

---向玩家发送消息，会主动加载玩家
function CMD.SendUser(uid, cmd, ...)
    local u, err = PullUser(uid)
    if not u then
        moon.error(err)
        return
    end

    if u.logouttime > 0 then
        u.logouttime = moon.time()
    end

    moon.send("lua", u.addr_user, cmd,...)
end

---向已经在内存的玩家发送消息,不会主动加载玩家
function CMD.SendMemUser(uid, cmd, ...)
    local u = context.uid_map[uid]
    if not u then
        return
    end
    moon.send("lua", u.addr_user, cmd,...)
end

function CMD.Disconnect(uid)
    local u = context.uid_map[uid]
    if u then
        moon.co_call("lua", u.addr_user, "User.Logout")
        u.logouttime = moon.time()
    end
end

return CMD


