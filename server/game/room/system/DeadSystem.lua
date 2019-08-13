local entitas = require("entitas")
local Components = require("room.Components")
local aoi = require("room.aoi")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local M = class("DeadSystem", ReactiveSystem)

---@param context room_context
function M:ctor(context)
    M.super.ctor(self, context.ecs_context)
    self.context = context
    self.idx = context.uid_index--用来根据id查询玩家entity
end

local trigger = {
    {
        Matcher({Components.Dead}),
        GroupEvent.ADDED | GroupEvent.UPDATE
    }
}

function M:get_trigger()
    unused(self)
    return trigger
end

function M:filter(entity)
    unused(self)
    return entity:has(Components.Dead)
end

function M:execute(entites)
    local num = 0
    entites:foreach(function( ne )
        local p =  ne:get(Components.BaseData)
        local isfood = ne:has(Components.Food)
        aoi.erase(p.id, not isfood)
        self.context.ecs_context:destroy_entity(ne)
        if not isfood then
            print("mover dead",p.id)
            self.context.send(p.id,"S2CDead",{id=p.id})
        end
        if isfood then
            num = num +1
        end
    end)

    self.context.docmd(0,0,"CreateFood",num)
end

return M
