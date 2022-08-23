local moon = require("moon")
local common = require("common")

local conf = ...

---@class center_context
local context ={
    conf = conf,
    match_map={},
    match_queue={},
    docmd = nil,
    addr_gate = 0,
    addr_auth = 0,
}

context.send_mem_user = function(uid, ...)
    moon.send("lua", context.addr_auth, "Auth.SendMemUser", uid, ...)
end

common.setup(context)
