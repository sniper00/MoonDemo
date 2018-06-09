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
                if oe:has(Components.Mover) then
                    local pos = oe:get(Components.Position)
                    local dir = oe:get(Components.Direction).value
                    local basedata = oe:get(Components.BaseData)
                    local speed = oe:get(Components.Speed).value
                    local radius = oe:get(Components.Radius).value
                    self.net.send(p.id,'S2CEnterViewPlayer',{x=pos.x,y=pos.y,dir=dir,speed = speed,radius = radius,id = basedata.id,name=basedata.name,spriteid =basedata.spriteid})
                else
                    local pos = oe:get(Components.Position)
                    local basedata = oe:get(Components.BaseData)
                    local radius = oe:get(Components.Radius)
                    self.net.send(p.id,'S2CEnterViewFood',{x=pos.x,y=pos.y,radius = radius,id = basedata.id,spriteid =basedata.spriteid})      
                end
                print("EnterView", otherid,"->",p.id)
            end
        end
        entity:remove(Components.EnterView)
    end)
end

return M
