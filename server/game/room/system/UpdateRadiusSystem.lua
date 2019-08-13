local entitas = require("entitas")
local Components = require("room.Components")
local aoi = require("room.aoi")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local M = class("UpdateRadiusSystem", ReactiveSystem)

function M:ctor(context)
    M.super.ctor(self, context.ecs_context)
    self.context = context
    self.idx = context.uid_index--用来根据id查询玩家entity
    self.cfg = context.conf
end

local trigger = {
    {
        Matcher({Components.Radius,Components.Mover}),
        GroupEvent.ADDED | GroupEvent.UPDATE
    }
}

function M:get_trigger()
    unused(self)
    return trigger
end

local all_comps = {Components.Radius,Components.Mover}

function M:filter(entity)
    unused(self)
    return entity:has_all(all_comps)
end

function M:execute(entites)
    entites:foreach(function(entity)
        local eid = entity:get(Components.BaseData).id
        local rdsid = self.context.make_prefab(entity,Components.Radius)
        self.context.send_prefab(eid,rdsid)
        local near = aoi.get_aoi(eid)
        if not near then
            return
        end
        for id,_ in pairs(near) do
            local ne = self.idx:get_entity(id)
            if ne and ne:has(Components.Mover) then
                self.context.send_prefab(id,rdsid)
            end
        end
    end)
end

return M
