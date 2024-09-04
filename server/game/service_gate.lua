local moon = require("moon")
local seri = require("seri")
local socket = require("moon.socket")
local websocket = require("moon.http.websocket")
local common = require("common")
local buffer = require("buffer")
local setup = common.setup
local protocol = common.protocol_pb
local GameDef = common.GameDef

local conf = ...

local redirect = moon.redirect

local PTYPE_C2S = GameDef.PTYPE_C2S

---@class gate_context:base_context
---@field scripts gate_scripts
local context = {
    conf = conf,
    uid_map = {},
    fd_map = {},
    auth_watch = {},
}

setup(context)

if conf.websocket then
    websocket.on_accept(function(fd, msg)
        print("GAME SERVER: accept ", fd, moon.decode(msg, "Z"))
        --socket.settimeout(fd, 60)
    end)

    websocket.wson("message", function(fd, msg)
        local c = context.fd_map[fd]
        if not c then
            ---first message must be auth message
            context.auth_watch[fd] = tostring(msg)
            local name, req = protocol.decode(moon.decode(msg, "B"))
            req.sign = context.auth_watch[fd]
            req.fd = fd
            req.addr = socket.getaddress(fd)
            req.pull = false
            moon.send("lua", context.addr_auth, name, req)
        else
            if moon.DEBUG() then
                local buf = moon.decode(msg, "B")
                protocol.print_message(c.uid, buf)
            end

            redirect(msg, c.addr_user, PTYPE_C2S, 0, 0)
        end
    end)

    websocket.wson("close", function(fd, msg)
        local data = moon.decode(msg, "Z")
        context.auth_watch[fd] = nil
        local c = context.fd_map[fd]
        if not c then
            print("GAME SERVER: close", fd, data)
            return
        end
        context.fd_map[fd] = nil
        context.uid_map[c.uid] = nil
        moon.send('lua', context.addr_auth, "Auth.Disconnect", c.uid)
        print("GAME SERVER: close", fd, c.uid, data)
    end)

    moon.raw_dispatch("S2C", function(msg)
        local buf = moon.decode(msg, "L")
        local uid = seri.unpack_one(buf, true)
        if type(uid) == "number" then
            local c = context.uid_map[uid]
            if not c then
                return
            end

            websocket.write(c.fd, buf)
            if moon.DEBUG() then
                protocol.print_message(uid, buf)
            end
        else
            local p = buffer.to_shared(buf)
            for _, one in ipairs(uid) do
                local c = context.uid_map[one]
                if c then
                    websocket.write(c.fd, p)
                    if moon.DEBUG() then
                        protocol.print_message(one, buf)
                    end
                end
            end
        end
    end)

    moon.raw_dispatch("SBC", function(msg)
        local buf = moon.decode(msg, "L")
        local p = buffer.to_shared(buf)
        for uid, c in pairs(context.uid_map) do
            websocket.write(c.fd, p)
            if moon.DEBUG() then
                protocol.print_message(uid, buf)
            end
        end
    end)
else
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
            local name, req = protocol.decode(moon.decode(msg, "B"))
            req.sign = context.auth_watch[fd]
            req.fd = fd
            req.addr = socket.getaddress(fd)
            req.pull = false
            moon.send("lua", context.addr_auth, name, req)
        else
            if moon.DEBUG() then
                local buf = moon.decode(msg, "B")
                protocol.print_message(c.uid, buf)
            end

            redirect(msg, c.addr_user, PTYPE_C2S, 0, 0)
        end
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
        moon.send('lua', context.addr_auth, "Auth.Disconnect", c.uid)
        print("GAME SERVER: close", fd, c.uid, data)
    end)

    moon.raw_dispatch("S2C", function(msg)
        local buf = moon.decode(msg, "L")
        local uid = seri.unpack_one(buf, true)
        if type(uid) == "number" then
            local c = context.uid_map[uid]
            if not c then
                return
            end

            socket.write(c.fd, buf)
            if moon.DEBUG() then
                protocol.print_message(uid, buf)
            end
        else
            local p = buffer.to_shared(buf)
            for _, one in ipairs(uid) do
                local c = context.uid_map[one]
                if c then
                    socket.write(c.fd, p)
                    if moon.DEBUG() then
                        protocol.print_message(one, buf)
                    end
                end
            end
        end
    end)

    moon.raw_dispatch("SBC", function(msg)
        local buf = moon.decode(msg, "L")
        local p = buffer.to_shared(buf)
        for uid, c in pairs(context.uid_map) do
            socket.write(c.fd, p)
            if moon.DEBUG() then
                protocol.print_message(uid, buf)
            end
        end
    end)
end
