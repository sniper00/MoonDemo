local moon = require("moon")
local common = require("common")

local conf = ...

---@class mail_context:base_context
---@field scripts mail_scripts
local context ={
    conf = conf,
    models = {},
    uid_address = {}
}

common.setup(context,"mail")

moon.shutdown(function()
    --- rewrite default behavior: quit immediately
end)
