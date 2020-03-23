local entitas = require("entitas")
local Components = require("room.Components")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local M = class("EatSystem", ReactiveSystem)

function M:ctor(context)
    M.super.ctor(self, context.ecs_context)
    self.idx = context.uid_index--用来根据id查询玩家entity
    self.movers = context.ecs_context:get_group(Matcher({Components.Mover}))
end

local trigger = {
    {
        Matcher({Components.Eat}),
        GroupEvent.ADDED | GroupEvent.UPDATE
    }
}

function M:get_trigger()
    unused(self)
    return trigger
end

function M:filter(entity)
    unused(self)
    return entity:has(Components.Eat)
end

function M:execute(entites)
    unused(self)
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
