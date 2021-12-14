local moon = require("moon")
local seri = require("seri")
local socket = require("moon.socket")
local constant = require("common.constant")
local setup = require("common.setup")
local protocol = require("common.protocol")

local conf = ...

local redirect = moon.redirect

local PCLIENT = constant.PTYPE_CLIENT

---@class gate_context
local context = {
    conf = conf,
    uid_map = {},
    fd_map = {},
    auth_watch = {},
    ---other service address
    addr_auth = false,
}

setup(context)

socket.on("accept", function(fd, msg)
    print("GAME SERVER: accept ", fd, moon.decode(msg, "Z"))
    socket.set_enable_chunked(fd, "w")
    --socket.settimeout(fd, 60)
end)

socket.on("message", function(fd, msg)
    local c = context.fd_map[fd]
    if not c then
        ---first message must be auth message
        context.auth_watch[fd] = tostring(msg)
        local name, req = protocol.decode(moon.decode(msg,"B"))
        req.sign = context.auth_watch[fd]
        req.fd = fd
        req.addr = socket.getaddress(fd)
        moon.send("lua", context.addr_auth, name, req)
    else
        redirect(msg, "", c.addr_user, PCLIENT, 0, 0)
    end
end)

socket.on("error", function(fd, msg)
    print("error ", fd, moon.decode(msg, "Z"))
end)

socket.on("close", function(fd, msg)
    local data = moon.decode(msg, "Z")
    context.auth_watch[fd] = nil
    local c = context.fd_map[fd]
    if not c then
        print("GAME SERVER: close", fd, data)
        return
    end
    context.fd_map[fd] = nil
    context.uid_map[c.uid] = nil
    moon.send('lua', context.addr_auth, "Disconnect", c.uid)
    print("GAME SERVER: close", fd, c.uid, data)
end)

moon.dispatch("toclient",function(msg)
    local uid = seri.unpack(moon.decode(msg, "H"))
    local c = context.uid_map[uid]
    if not c then
        return
    end
    socket.write_message(c.fd,msg)
end)



