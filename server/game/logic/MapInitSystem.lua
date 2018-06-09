local entitas    = require('entitas')
local Components = require('Components')
local util       = require("util")
local ComponentsIndex = require("ComponentsIndex")
local class      = util.class
local ReactiveSystem = entitas.ReactiveSystem
local Matcher    = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local M = class("FoodInitSystem")

function M:ctor(contexts,helper)
    self.context = contexts.input
    self.input_entity = self.context.input_entity
end

function M:initialize()
    -- 初始化100个food
    self.input_entity:replace(Components.InputCreateFood,100)
end

return M
