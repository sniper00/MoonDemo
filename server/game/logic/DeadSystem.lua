local require = require("import")
local entitas = require("entitas")
local Components = require("Components")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local M = class("DeadSystem", ReactiveSystem)

function M:ctor(contexts, helper)
    M.super.ctor(self, contexts.game)
    self.context = contexts.game
    self.input_entity = contexts.input.input_entity
    self.aoi = helper.aoi
    self.net = helper.net
end

local trigger = {
    {
        Matcher({Components.Dead}),
        GroupEvent.ADDED | GroupEvent.UPDATE
    }
}

function M:get_trigger()
    return trigger
end

function M:filter(entity)
    return entity:has(Components.Dead)
end

function M:execute(entites)
    local num = 0
    entites:foreach(function( ne )
        local p =  ne:get(Components.BaseData)
        local isfood = ne:has(Components.Food)
        self.aoi.erase(p.id, not isfood)
        self.context:destroy_entity(ne)
        if not isfood then
            print("mover dead",p.id)
            self.net.send(p.id,"S2CDead",{id=p.id})
        end
        if isfood then
            num = num +1
        end
    end)
    self.input_entity:replace(Components.InputCreateFood,num)
end

return M
