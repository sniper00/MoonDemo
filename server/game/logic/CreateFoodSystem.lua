local require = require("import")
local class = class or require("base.class")
local entitas = require("entitas")
local Components = require("Components")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local M = class("CreateFoodSystem", ReactiveSystem)

local fooduid = 1000000

function M:ctor(contexts, helper)
    M.super.ctor(self, contexts.input)
    self.context = contexts.game
    self.input_entity = contexts.input.input_entity
    self.aoi = helper.aoi
    self.cfg = helper.cfg
end

local trigger =  {
    {
        Matcher({Components.InputCreateFood}),
        GroupEvent.ADDED | GroupEvent.UPDATE
    }
}

function M:get_trigger()
    return trigger
end

function M:filter(entity)
    return entity:has(Components.InputCreateFood)
end

function M:execute()
    local count = self.input_entity:get(Components.InputCreateFood).count
    for i = 1, count do
        local food = self.context:create_entity()
        local x = math.random(self.cfg.min_edge, self.cfg.max_edge)
        local y = math.random(self.cfg.min_edge, self.cfg.max_edge)
        local spriteid = math.random(1,12)
        food:add(Components.Position, x, y)
        food:add(Components.BaseData, fooduid, "",spriteid)
        food:add(Components.Food)
        food:add(Components.Radius, self.cfg.food_raduis)
        self.aoi.update_pos(fooduid, "m", x, y)
        fooduid = fooduid + 1
    end
    self.aoi.update_message()
end

return M
