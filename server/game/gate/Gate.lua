local moon = require("moon")
local socket = require("moon.socket")

---@type gate_context
local context = ...

local listenfd

local CMD = {}

function CMD.Init()
    context.addr_auth = moon.queryservice("auth")
    return true
end

function CMD.Start()
    ---开始接收客户端网络链接
    listenfd  = socket.listen(context.conf.host, context.conf.port, moon.PTYPE_SOCKET_MOON)
    assert(listenfd>0,"server listen failed")
    socket.start(listenfd)
    print("GAME Server Start Listen",context.conf.host, context.conf.port)
    return true
end

function CMD.Shutdown()
    for _, c in pairs(context.uid_map) do
        socket.close(c.fd)
    end
    if listenfd then
        socket.close(listenfd)
    end
    moon.quit()
    return true
end

function CMD.Kick(uid, fd, ignore_socket_event)
    print("gate kick", uid, fd, ignore_socket_event)
    if uid and uid >0 then
        local c = context.uid_map[uid]
        if c then
            socket.close(c.fd)
        end
        if ignore_socket_event then
            context.fd_map[c.fd] = nil
            context.uid_map[uid] = nil
        end
    end

    if fd and fd>0 then
        socket.close(fd)
    end
    return true
end

function CMD.BindUser(req)
    if context.auth_watch[req.fd] ~= req.sign then
        return false, "client closed before auth done!"
    end
    local old = context.uid_map[req.uid]
    if old and old.fd ~= req.fd then
        context.fd_map[old.fd] = nil
        socket.close(old.fd)
        print("kick user", req.uid, "oldfd", old.fd, "newfd", req.fd)
    end

    local c = {
        uid = req.uid,
        fd = req.fd,
        addr_user = req.addr_user
    }

    context.fd_map[req.fd] = c
    context.uid_map[req.uid] = c
    context.auth_watch[req.fd] = nil
    print(string.format("BindUser %d %d %08X", req.fd, req.uid,  req.addr_user))
    return true
end

return CMD