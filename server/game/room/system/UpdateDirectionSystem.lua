local entitas = require("entitas")
local Components = require("room.Components")
local aoi = require("room.aoi")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local M = class("UpdateDirectionSystem", ReactiveSystem)

function M:ctor(context)
    M.super.ctor(self, context.ecs_context)
    self.context = context
    self.idx = context.uid_index--用来根据id查询玩家entity
    self.cfg = context.conf
end

local trigger = {
    {
        Matcher({Components.Direction,Components.Mover}),
        GroupEvent.ADDED | GroupEvent.UPDATE
    }
}

function M:get_trigger()
    unused(self)
    return trigger
end

local all_comps = {Components.Direction,Components.Mover}

function M:filter(entity)
    unused(self)
    return entity:has_all(all_comps)
end

function M:execute(entites)
    entites:foreach(function(entity)
        local eid = entity:get(Components.BaseData).id
        local dirid = self.context.make_prefab(entity,Components.Direction)
        local posid = self.context.make_prefab(entity,Components.Position)
        self.context.send_prefab(eid,dirid)
        self.context.send_prefab(eid,posid)
        aoi.fire_event(eid,aoi.EVENT_UPDATE_DIR,function (watcher)
            local ne = self.idx:get_entity(watcher)
            if ne and ne:has(Components.Mover) then
                self.context.send_prefab(watcher,dirid)
                self.context.send_prefab(watcher,posid)
            end
        end)
    end)
end

return M
