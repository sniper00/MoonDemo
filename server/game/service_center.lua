local moon = require("moon")
local setup = require("common.setup")

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

context.send_online_user = function(uid, ...)
    moon.send("lua", context.addr_auth, "SendOnlineUser", uid, ...)
end

context.docmd = setup(context)
