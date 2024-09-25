local moon = require("moon")
local setup = require("common.setup")
local conf = ...

---@class mail_context:base_context
---@field scripts mail_scripts
local context ={
    conf = conf,
    models = {},
    uid_address = {}
}

setup(context,"mail")

moon.shutdown(function()
    --- rewrite default behavior: quit immediately
end)
