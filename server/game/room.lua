local moon = require("moon")
local seri = require("seri")
local setup = require("common.setup")
local msgutil = require("common.msgutil")

local conf = ...

---@class room_context
local context ={
    conf = conf,
    models = {},
    docmd = false,
    uid_address = {},
    addr_gate = false,
    addr_auth = false
}

local docmd = setup(context,"room")
context.docmd = docmd

context.addr_gate = moon.queryservice("gate")
context.addr_auth = moon.queryservice("auth")
context.addr_center = moon.queryservice("center")

context.send = function(uid, msgid, mdata)
    moon.raw_send('toclient', context.addr_gate, seri.packs(uid), msgutil.encode(msgid,mdata))
end

context.send_user = function(uid, ...)
    moon.send("lua", context.addr_auth, "", "SendUser", uid, ...)
end

context.send_online_user = function(uid, ...)
    moon.send("lua", context.addr_auth, "", "SendOnlineUser", uid, ...)
end

docmd("Init")

moon.repeated(100,-1,function()
    docmd("Update")
end)

moon.repeated(conf.round_time*1000, 1, function()
    docmd("GameOver")
end)

moon.shutdown(function()
    --- rewrite default behavior: quit immediately
end)
