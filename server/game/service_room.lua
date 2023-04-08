require("common.LuaPanda").start("127.0.0.1", 8818)
local moon = require("moon")
local common = require("common")

local conf = ...

---@class room_context:base_context
---@field scripts room_scripts
local context ={
    conf = conf,
    models = {},
    docmd = false,
    uid_address = {},
    addr_gate = 0,
    addr_auth = 0,
    addr_center = 0
}

common.setup(context,"room")

moon.shutdown(function()
    --- rewrite default behavior: quit immediately
end)
