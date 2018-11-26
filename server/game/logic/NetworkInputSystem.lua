local entitas    = require('entitas')
local Components = require('Components')
local util       = require("util")
local ComponentsIndex = require("ComponentsIndex")
local class      = util.class

local M = class("NetworkInputSystem")

function M:ctor(contexts)
    self.input_entity = contexts.input.input_entity
end

function M:dispatch(id,...)
    local comp = ComponentsIndex[id]
    assert(comp,"unknown comp "..string.format( "0x%04x",id))
    self.input_entity:replace(comp,...)
    --print("net_input",comp)
end

return M
