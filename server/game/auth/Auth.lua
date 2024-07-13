local moon = require("moon")
local uuid = require("uuid")
local queue = require("moon.queue")
local common = require("common")

local db = common.Database
local CmdCode = common.CmdCode

local traceback = debug.traceback

local mem_player_limit = 0 --内存中最小玩家数量
local min_online_time = 60 --seconds，logout间隔大于这个时间的,并且不在线的,user服务会被退出

---@type auth_context
local context = ...

local auth_queue = context.auth_queue
local temp_openid_uid = {}

local function doAuth(req)
    local u = context.uid_map[req.uid]
    local addr_user
    if not u then
        local conf = {
            name = "user"..req.uid,
            file = "game/service_user.lua"
        }
        addr_user = moon.new_service(conf)
        if addr_user == 0 then
            return "create user service failed!"
        end

        local ok, err = moon.call("lua", addr_user, "User.Load", req)
        if not ok then
            moon.send("lua", context.addr_gate, "Gate.Kick", 0, req.fd)
            moon.kill(addr_user)
            context.uid_map[req.uid] = nil
            return err
        end
    else
        addr_user = u.addr_user
    end

    local openid, err = moon.call("lua", addr_user, "User.Login", req)
    if not openid then
        print(openid, err)
        moon.send("lua", context.addr_gate, "Gate.Kick", 0, req.fd)
        moon.kill(addr_user)
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
        print("login success", req.uid)
    else
        print("login failed", req.uid)
    end

    moon.send("lua", context.addr_gate, "Gate.BindUser", req)

    local res = {
        ok = pass,---maybe banned
        time = moon.now(),
        timezone = moon.timezone,
        uid = req.uid,
    }
    context.S2C(req.uid, CmdCode.S2CLogin, res)
end

local function QuitOneUser(u)
    moon.send("lua", u.addr_user, "User.Exit")
    context.uid_map[u.uid] = nil
end

---@class Auth
local Auth = {}

Auth.Init = function()

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

Auth.Start = function()
    context.start_hour_timer()
    return true
end

Auth.Shutdown = function()
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

Auth.OnHour = function(v)
    print("OnHour", v)
    for _,u in pairs(context.uid_map) do
        if u.logouttime == 0 then
            moon.send("lua", u.addr_user, "User.OnHour", v)
        end
    end
end

Auth.OnDay = function(v)
    print("OnDay", v)
    for _,u in pairs(context.uid_map) do
        if u.logouttime == 0 then
            moon.send("lua", u.addr_user, "User.OnDay", v)
        end
    end
end

Auth.C2SLogin = function (req)

    if not req then
        return false
    end

    ---pull boolean @是否离线加载玩家
    if not req.pull then
        if not req.openid or #req.openid == 0 then
            moon.error("user auth illegal", req.fd, req.openid)
            moon.send("lua", context.addr_gate, "Gate.Kick", 0, req.fd)
            return false
        end

        ---如果是opendid登录, 先得到openid对应的 uid
        local uid = context.openid_map[req.openid]
        if not uid then
            ---避免同一个玩家瞬间发送大量登录请求
            uid = temp_openid_uid[req.openid]
            if not uid then
                uid = uuid.next()
                temp_openid_uid[req.openid] = uid
            end

            local res, err = db.insertuserid(context.addr_db_openid, req.openid, uid)
            if not res then
                moon.error("insertuserid", req.fd, req.openid, err)
                moon.send("lua", context.addr_gate, "Gate.Kick", 0, req.fd)
                return false
            end

            temp_openid_uid[req.openid] = nil
            context.openid_map[req.openid] = uid
        end
        req.uid = uid
    else
        req.openid = ""
        if not req.uid or req.uid == 0 then
            if req.fd then
                moon.error("user auth illegal", req.fd, req.uid)
                moon.send("lua", context.addr_gate, "Gate.Kick", 0, req.fd)
            end
            return false
        end
    end

    ---服务器关闭时,中断所有客户端的登录请求
    if context.server_exit and not req.pull then
        return false, "auth abort"
    end

    local lock = auth_queue[req.uid]
    if not lock then
        lock = queue()
        auth_queue[req.uid] = lock
    end

    if not req.pull then
        if lock("count") > 0 then
            moon.error("user auth too quickly", req.fd, req.uid, req.addr, "is pull:", req.pull)
            moon.send("lua", context.addr_gate, "Gate.Kick", 0, req.fd)
            return
        end
        ---user may login again, but old socket not close,force close it
        ---make the user offline event in right order.
        local c = context.uid_map[req.uid]
        if c and c.logouttime==0 then
            moon.send("lua", context.addr_gate, "Gate.Kick", req.uid, 0, true)
            Auth.Disconnect(req.uid)
            return
        end
    end

    local scope_lock<close> = lock()

    if req.pull and context.uid_map[req.uid] then
        return true
    end

    print(string.format("User Login fd:%d uid:%d pulluser:%s", req.fd, req.uid, req.pull))

    if not req.pull then
        moon.timeout(5000, function ()
            if context.uid_map[req.uid] then
                return
            end

            local res = {
                ok = false,---maybe banned
                time = moon.now(),
                timezone = moon.timezone,
                uid = req.uid,
            }
            context.S2C(req.uid, CmdCode.S2CLogin, res)
        end)
    end

    local ok, err = xpcall(doAuth, traceback, req)
    if not ok or err then
        moon.error("Auth.C2SLogin Error", err, table.tostring(req))
        return false, err
    end
    return true
end

---加载离线玩家
function Auth.PullUser(uid)
    local u = context.uid_map[uid]
    if not u then
        local ok,err = Auth.C2SLogin({fd =0 ,uid = uid, pull = true})
        if not ok then
            return ok, err
        end
        u = context.uid_map[uid]
    end
    return u
end

---向玩家发起调用，会主动加载玩家
function Auth.CallUser(uid, cmd, ...)
    if context.server_exit then
        error(string.format("call user %d cmd %s when server exit", uid, cmd))
    end

    local u, err = Auth.PullUser(uid)
    if not u then
        return false, err
    end

    if u.logouttime > 0 then
        u.logouttime = moon.time()
    end

    return moon.call("lua", u.addr_user, cmd, ...)
end

---向玩家发送消息，会主动加载玩家
function Auth.SendUser(uid, cmd, ...)
    local u, err = Auth.PullUser(uid)
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
function Auth.TrySendUser(uid, cmd, ...)
    local u = context.uid_map[uid]
    if not u then
        return
    end
    moon.send("lua", u.addr_user, cmd,...)
end

function Auth.Disconnect(uid)
    local u = context.uid_map[uid]
    if u then
        assert(moon.call("lua", u.addr_user, "User.Logout"))
        u.logouttime = moon.time()
    end
end

return Auth


