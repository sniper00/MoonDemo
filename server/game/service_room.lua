local moon = require("moon")
local setup = require("common.setup")
local conf = ...

---@class room_context:base_context
---@field scripts room_scripts
local context ={
    conf = conf,
    models = {},
    uid_address = {}
}

setup(context,"room")

moon.shutdown(function()
    --- rewrite default behavior: quit immediately
end)
