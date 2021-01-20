local moon = require("moon")
local json = require("json")
local dbutil = require("common.dbutil")
local msgcode = require("common.msgcode")
local constant = require("common.constant")

local traceback = debug.traceback

local mem_player_limit = 10 --内存中最小玩家数量
local min_online_time = 300 --seconds，logout间隔大于这个时间的,并且不在线的,user服务会被退出

---@type auth_context
local context = ...

local token_watch = {}

local wait_queue = {}

moon.repeated(10000,-1,function(timerid)
    if context.server_exit then
        moon.remove_timer(timerid)
        return
    end

    local now = moon.time()

    if context.uid_map_count < mem_player_limit then
        return
    end

    for _,u in pairs(context.uid_map) do
        if not u.online and (now - u.logouttime) > min_online_time then
            moon.send("lua", u.addr_user, "Exit")
            context.uid_map[u.uid] = nil
            context.uid_map_count = context.uid_map_count - 1
        end
    end
end)

local function WakeUpAuthQueue(uid)
    local q = wait_queue[uid]
    if q then
        wait_queue[uid] = nil
        moon.async(function()
            moon.sleep(10)
            while #q > 0 do
                local co = table.remove(q, 1)
                local ok, err = coroutine.resume(co)
                if not ok then
                    moon.error(err)
                end
            end
        end)
    end
end

local function _DoAuth(req)
    local u = context.uid_map[req.uid]
    local addr_user
    if not u then
        local conf = {
            name = "user"..req.uid,
            file = "game/user.lua",
            user_db = context.user_db,
        }
        addr_user = moon.new_service("lua", conf)
    else
        addr_user = u.addr_user
    end

    local ok, err = moon.co_call("lua", addr_user, "Init", req)
    if not ok then
        moon.send("lua", context.addr_gate, "KickByFd", req.fd)
        moon.remove_service(addr_user)
        context.uid_map[req.uid] = nil
        return err
    end

    local openid = ok

    if not u then
        u = {
            addr_user = addr_user,
            openid = openid,
            uid = req.uid,
            logouttime = moon.time(),
            online = false
        }

        context.uid_map[req.uid] = u
        context.uid_map_count = context.uid_map_count + 1
    end

    if req.isload then
        return
    end

    req.addr_user = addr_user

    ok, err = moon.co_call("lua", context.addr_gate, "SetFdUid", req)
    if not ok then
        return err
    end

    local res = {
        ok = true,---maybe banned
        time = moon.now(),
        timezone = moon.timezone
    }

    context.send(req.uid, msgcode.S2CLogin, res)

    if res.ok then
        u.online = true
        print(req.uid, "login success")
    else
        print(req.uid, "login failed")
    end
end

local function SaveUser()
    local count  = 0
    for _,u in pairs(context.uid_map) do
        moon.co_call("lua", u.addr_user, "Exit")
        count = count + 1
    end
    return count
end

local CMD = {}

CMD._hotfix = function(names)
    for _,u in pairs(context.uid_map) do
        moon.send("lua", u.addr_user, "_hotfix", names)
    end
end

CMD.Init = function()
    context.addr_gate = moon.queryservice("gate")
    context.addr_db_openid = moon.queryservice("db_openid")
    context.addr_db_server = moon.queryservice("db_server")

    local data = dbutil.loadserverdata(context.addr_db_server)
    if not data then
        data = {start_times = 0}
    else
        data = json.decode(data)
    end
    data.start_times = data.start_times + 1
    moon.set_env("SERVER_START_TIMES", tostring(data.start_times))
    assert(dbutil.saveserverdata(context.addr_db_server, json.encode(data)))
    return true
end

CMD.Start = function()

    context.start_hour_timer()
    return true
end

CMD.RemoveAllUser = function()
    for _,u in pairs(context.uid_map) do
        moon.remove_service(u.addr_user, true)
    end
end

CMD.Shutdown = function()
    context.server_exit = true
    local ok, err = xpcall(SaveUser,debug.traceback)
    print("server exit save user", ok, err)
    moon.quit()
    return true
end

CMD.OnHour = function(v)
    print("OnHour", v)
    for _,u in pairs(context.uid_map) do
        if u.online then
            moon.send("lua", u.addr_user, "OnHour", v)
        end
    end
end

CMD.OnDay = function(v)
    print("OnDay", v)
    for _,u in pairs(context.uid_map) do
        if u.online then
            moon.send("lua", u.addr_user, "OnDay", v)
        end
    end
end

---@param isload boolean @是否服务器离线加载玩家
CMD.Auth = function (fd, req, addr, isload)
    if not req or not (req.openid or req.uid) then
        return false
    end

    isload = isload or false

    if req.openid then
        local uid = context.openid_map[req.openid]
        if not uid then
            ---yield
            uid = dbutil.queryuserid(context.addr_db_openid, req.openid)
            if false == uid then
                moon.error("user auth load query userid db error", req.openid)
                moon.send("lua", context.addr_gate, "KickByFd", fd)
                return
            elseif uid == nil then
                ---may has created, because of yield, check again
                uid = context.openid_map[req.openid]
                if not uid  then
                    uid = constant.MakeUUID(constant.Type.Player)
                    dbutil.insertuserid(context.addr_db_openid, req.openid, uid)
                end
            end
            context.openid_map[req.openid] = uid
        end
        req.uid = uid
    else
        req.openid = ""
    end

    if type(req.uid) ~= "number" then
        moon.error("user auth illegal", fd, req.uid, type(req.uid))
        moon.send("lua", context.addr_gate, "KickByFd", fd)
        return false
    end

    --- user may send many auth request, check it
    if token_watch[req.uid] then
        moon.error("user auth too quickly", fd, req.uid, addr, isload)
        moon.send("lua", context.addr_gate, "KickByFd", fd)
        return false
    end

    print("user auth", fd, req.uid, isload)

    req.fd = fd
    req.addr = addr
    req.isload = isload

    token_watch[req.uid] = true
    local ok, err = xpcall(_DoAuth, traceback, req)
    token_watch[req.uid] = nil
    if not ok or err then
        moon.error("CMD.Auth Error", table.tostring(err) )
        return err
    end
    return
end

---加载离线玩家
local function OfflineAuth(uid)
   ---有可能玩家正在登录，等待玩家登录流程结束
   if token_watch[uid] then
        local q = wait_queue[uid]
        if not q then
            q = {}
            wait_queue[uid] = q
        end
        local co = coroutine.running()
        table.insert(q, co)
        coroutine.yield()
    end

    local u = context.uid_map[uid]
    if not u then
        local ok,err = CMD.Auth(0, {uid = uid} , "", true)
        if not ok then
            return ok,err
        end
    end

    WakeUpAuthQueue(uid)
    return true
end

function CMD.CallUser(uid, cmd, ...)
    local u = context.uid_map[uid]
    if not u then
        local ok, err = OfflineAuth(uid)
        if not ok then
            return ok, err
        end
    end
    u = context.uid_map[uid]
    return moon.co_call("lua", u.addr_user, cmd, ...)
end

function CMD.SendUser(uid, cmd, ...)
    local u = context.uid_map[uid]
    if not u then
        local ok, err = OfflineAuth(uid)
        if not ok then
            return ok, err
        end
    end
    u = context.uid_map[uid]
    moon.send("lua", u.addr_user, cmd,...)
end

---向玩家所在服务发送消息,不在线不发送
function CMD.SendOnlineUser(uid, cmd, ...)
    local u = context.uid_map[uid]
    if not u then
        return
    end
    moon.send("lua", u.addr_user, cmd,...)
end

function CMD.OffLine(uid)
    local u = context.uid_map[uid]
    if u then
        moon.co_call("lua", u.addr_user, "OffLine")
        u.online = false
        u.logouttime = moon.time()
    end
end

return CMD


