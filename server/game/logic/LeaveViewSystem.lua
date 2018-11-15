local util = require("util")
local entitas = require("entitas")
local Components = require("Components")
local vector2 = require("vector2")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local class = util.class

local M = class("LeaveViewSystem", ReactiveSystem)

function M:ctor(contexts, helper)
    M.super.ctor(self, contexts.game)
    self.net = helper.net
end

function M:get_trigger()
    return {
        {
            Matcher({Components.LeaveView}),
            GroupEvent.ADDED | GroupEvent.UPDATE
        }
    }
end

function M:filter(entity)
    return entity:has(Components.LeaveView)
end

function M:execute(entites)
    entites:foreach(function( entity )
        local p =  entity:get(Components.BaseData)
        local others = entity:get(Components.LeaveView).ids
        for _,otherid in pairs(others) do
            self.net.send(p.id,'S2CLeaveView',{id=otherid})
            --print("LeaveView", otherid,"<->",p.id)
        end
        entity:remove(Components.LeaveView)
    end)
end

return M
