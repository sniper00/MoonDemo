local moon = require("moon")
local common = require("common")

local conf = ...

---@class node_context:base_context
local context ={
    addr_auth = 0,
    addr_gate = 0,
    logics = {},
    docmd = nil,
}

common.setup(context)

moon.shutdown(function()
    moon.quit()
end)
