local moon = require("moon")
local seri = require("seri")
local message = require("message")
local cluster = require("moon.cluster")
local socket = require("moon.socket")
local constant = require("common.constant")
local setup = require("common.setup")

local conf = ...

local PCLIENT = constant.PTYPE.CLIENT

---@class gate_context
local context = {
    conf = conf,
    openid_map = {},
    usertoken_map = {},
    connection = {},
    uid_map = {}
}

local docmd = setup(context)

local connection = context.connection

socket.on("accept", function(fd, msg)
    print("GAME SERVER: accept ", fd, moon.decode(msg, "Z"))
    socket.set_enable_chunked(fd, "w")
    --socket.settimeout(fd, 60)
end)

socket.on("message", function(fd, msg)
    local c = connection[fd]
    if not c or not c.agent then
        docmd(0,0,'auth', fd, moon.decode(msg, "Z"))
    else
        local agent = c.agent
        message.redirect(msg, "", agent, PCLIENT)
    end
end)

socket.on("error", function(fd, msg)
    print("error ", fd, moon.decode(msg, "Z"))
end)

socket.on("close", function(fd, msg)

    local c = connection[fd]
    if not c then
        print("gate client close ", fd, moon.decode(msg, "Z"))
        return
    end
    connection[fd] = nil
    context.uid_map[c.uid] = nil
    local agent = c.agent
    moon.send('lua', agent, nil,'disconnect')
    print("GATE: client close ", fd, c.openid,c.uid)
end)

moon.dispatch("toclient",function(msg)
    local uid = seri.unpack(moon.decode(msg, "H"))
    local fd = context.uid_map[uid]
    if not fd then
        return
    end
    socket.write_message(fd,msg)
end)



