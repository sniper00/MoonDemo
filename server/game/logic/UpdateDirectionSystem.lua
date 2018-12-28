local require = require("import")

local entitas = require("entitas")
local Components = require("Components")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local class =  require("util").class

local M = class("UpdateDirectionSystem", ReactiveSystem)

function M:ctor(contexts, helper)
    M.super.ctor(self, contexts.game)
    self.context = contexts.game
    self.net = helper.net
    self.movers = self.context:get_group(Matcher({Components.Mover}))
end

local trigger = {
    {
        Matcher({Components.Direction}),
        GroupEvent.ADDED | GroupEvent.UPDATE
    }
}

function M:get_trigger()
    return trigger
end

function M:filter(entity)
    return entity:has(Components.Direction)
end

function M:execute(entites)
    local movers = self.movers.entities
    entites:foreach(function(entity)
        local dirid = self.net.prepare(entity,Components.Direction)
        local posid = self.net.prepare(entity,Components.Position)
        movers:foreach(function(other)
                local id = other:get(Components.BaseData).id
                self.net.send_prepare(id,dirid)
                self.net.send_prepare(id,posid)
            end)
    end)
end

return M
