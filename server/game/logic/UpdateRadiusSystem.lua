local require = require("import")

local entitas = require("entitas")
local Components = require("Components")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local M = class("UpdateRadiusSystem", ReactiveSystem)

function M:ctor(contexts, helper)
    M.super.ctor(self, contexts.game)
    self.context = contexts.game
    self.net = helper.net
    self.aoi = helper.aoi
    self.idx = contexts.idx--用来根据id查询玩家entity
end

local trigger = {
    {
        Matcher({Components.Radius,Components.Mover}),
        GroupEvent.ADDED | GroupEvent.UPDATE
    }
}

function M:get_trigger()
    return trigger
end

local all_comps = {Components.Radius,Components.Mover}

function M:filter(entity)
    return entity:has_all(all_comps)
end

function M:execute(entites)
    entites:foreach(function(entity)
        local eid = entity:get(Components.BaseData).id
        local rdsid = self.net.make_prefab(entity,Components.Radius)
        self.net.send_prefab(eid,rdsid)
        local near = self.aoi.get_aoi(eid)
        if not near then
            return
        end
        for id,_ in pairs(near) do
            local ne = self.idx:get_entity(id)
            if ne and ne:has(Components.Mover) then
                self.net.send_prefab(id,rdsid)
            end
        end
    end)
end

return M
