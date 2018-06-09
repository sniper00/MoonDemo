local entitas    = require('entitas')
local Components = require('Components')
local util       = require("util")
local ComponentsIndex = require("ComponentsIndex")
local class      = util.class
local ReactiveSystem = entitas.ReactiveSystem
local Matcher    = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local M = class("NetworkInputSystem")

function M:ctor(contexts)
    self.input_entity = contexts.input.input_entity
end

function M:dispatch(id,...)
    local comp = ComponentsIndex[id]
    assert(comp,"unknown comp")
    self.input_entity:replace(comp,...)
    --print("net_input",comp)
end

return M
