local util = require("util")
local entitas = require("entitas")
local Components = require("Components")
local vector2 = require("vector2")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local class = util.class

local M = class("EnterViewSystem", ReactiveSystem)

function M:ctor(contexts, helper)
    M.super.ctor(self, contexts.game)
    self.idx = contexts.idx
    self.net = helper.net
end

function M:get_trigger()
    return {
        {
            Matcher({Components.EnterView}),
            GroupEvent.ADDED | GroupEvent.UPDATE
        }
    }
end

function M:filter(entity)
    return entity:has(Components.EnterView)
end

function M:execute(entites)
    entites:foreach(function( entity )
        local p =  entity:get(Components.BaseData)
        local others = entity:get(Components.EnterView).ids
        --print("player",p.id)
        for _,otherid in pairs(others) do
            local oe = self.idx:get_entity(otherid)
            if oe then
                self.net.send(p.id, "S2CEnterView", {id = otherid})

                if oe:has(Components.Mover) then
                    self.net.send_component(p.id,oe,Components.Speed)
                    self.net.send_component(p.id,oe,Components.Direction)
                    self.net.send_component(p.id,oe,Components.Mover)
                elseif oe:has(Components.Food) then
                    self.net.send_component(p.id,oe,Components.Food)
                end

                self.net.send_component(p.id,oe,Components.BaseData)
                self.net.send_component(p.id,oe,Components.Position)
                self.net.send_component(p.id,oe,Components.Radius)
                --print("EnterView", otherid,"->",p.id)
            end
        end
        entity:remove(Components.EnterView)
    end)
end

return M
