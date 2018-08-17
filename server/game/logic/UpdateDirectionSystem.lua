local util = require("util")
local entitas = require("entitas")
local Components = require("Components")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local class = util.class

local M = class("UpdateDirectionSystem", ReactiveSystem)

function M:ctor(contexts, helper)
    M.super.ctor(self, contexts.game)
    self.context = contexts.game
    self.net = helper.net
    self.movers = self.context:get_group(Matcher({Components.Mover}))
end

function M:get_trigger()
    return {
        {
            Matcher({Components.Direction}),
            GroupEvent.ADDED | GroupEvent.UPDATE
        }
    }
end

function M:filter(entity)
    return entity:has(Components.Direction)
end

function M:execute(entites)
    local movers = self.movers.entities
    entites:foreach(function(entity)
        movers:foreach(function(other)
                local id = other:get(Components.BaseData).id
                self.net.send_component(id,entity,Components.Direction)
                self.net.send_component(id,entity,Components.Position)
            end)
    end)
end

return M
