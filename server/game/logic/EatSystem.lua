local require = require("import")
local entitas = require("entitas")
local Components = require("Components")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local M = class("EatSystem", ReactiveSystem)

function M:ctor(contexts, helper)
    M.super.ctor(self, contexts.game)
    self.context = contexts.game
    self.net = helper.net
    self.movers = self.context:get_group(Matcher({Components.Mover}))
end

local trigger = {
    {
        Matcher({Components.Eat}),
        GroupEvent.ADDED | GroupEvent.UPDATE
    }
}

function M:get_trigger()
    return trigger
end

function M:filter(entity)
    return entity:has(Components.Eat)
end

function M:execute(entites)
    entites:foreach(function(e)
        local weight = e:get(Components.Eat).weight
        local radius = e:get(Components.Radius).value
        local newradius =radius + weight
        if newradius > 5 then
            newradius = 0.3
            print("radius too big")
        end
        e:replace(Components.Radius,newradius)
    end)
end

return M
