local moon = require("moon")
local common = require("common")

local conf = ...

---@class room_context:base_context
---@field scripts room_scripts
local context ={
    conf = conf,
    models = {},
    uid_address = {}
}

common.setup(context,"room")

moon.shutdown(function()
    --- rewrite default behavior: quit immediately
end)
