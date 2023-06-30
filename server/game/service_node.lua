local moon = require("moon")
local common = require("common")

local conf = ...

---@class node_context:base_context
---@field scripts node_scripts
local context ={
    addr_auth = 0,
    addr_gate = 0,
    logics = {},
}

common.setup(context)

moon.shutdown(function()
    moon.quit()
end)
