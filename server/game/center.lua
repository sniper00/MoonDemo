local moon = require("moon")
local seri = require("seri")
local setup = require("common.setup")
local msgutil = require("common.msgutil")

local conf = ...

---@class center_context
local context ={
    conf = conf,
    match_map={},
    match_queue={},
    docmd = false,
    addr_gate = false,
    addr_auth = false,
}

context.send = function(uid, msgid, mdata)
    moon.raw_send('toclient', context.addr_gate, seri.packs(uid), msgutil.encode(msgid,mdata))
end

context.send_online_user = function(uid, ...)
    moon.send("lua", context.addr_auth, "SendOnlineUser", uid, ...)
end

context.docmd = setup(context)
