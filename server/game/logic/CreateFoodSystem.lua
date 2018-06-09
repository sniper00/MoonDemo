local util = require("util")
local entitas = require("entitas")
local Components = require("Components")
local vector2 = require("vector2")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local class = util.class

local M = class("CreateFoodSystem", ReactiveSystem)

local fooduid = 1000000

function M:ctor(contexts, helper)
    M.super.ctor(self, contexts.input)
    self.context = contexts.game
    self.input_entity = contexts.input.input_entity
    self.aoi = helper.aoi
end

function M:get_trigger()
    return {
        {
            Matcher({Components.InputCreateFood}),
            GroupEvent.ADDED | GroupEvent.UPDATE
        }
    }
end

function M:filter(entity)
    return entity:has(Components.InputCreateFood)
end

function M:execute()
    local count = self.input_entity:get(Components.InputCreateFood).count
    for i = 1, count do
        local food = self.context:create_entity()
        local x = math.random(-20, 20)
        local y = math.random(-20, 20)
        local spriteid = math.random(1,12)
        food:add(Components.Position, x, y)
        food:add(Components.BaseData, fooduid, "",spriteid)
        food:add(Components.Food)
        food:add(Components.Radius, 0.2)
        self.aoi.add(fooduid)
        self.aoi.update_pos(fooduid, "m", x, y)
        fooduid = fooduid + 1
    end
    self.aoi.update_message()
end

return M
