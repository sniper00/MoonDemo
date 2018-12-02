local util = require("util")
local entitas = require("entitas")
local Components = require("Components")
local vector2 = require("vector2")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local class = util.class

local M = class("CreateMoverSystem", ReactiveSystem)

function M:ctor(contexts, helper)
    self.context = contexts.game
    M.super.ctor(self, contexts.input)
    self.input_entity = contexts.input.input_entity
    self.aoi = helper.aoi
    self.net = helper.net
    self.cfg = helper.cfg
end

local trigger = {
    {
        Matcher({Components.CommandCreate}),
        GroupEvent.ADDED | GroupEvent.UPDATE
    }
}

function M:get_trigger()
    return trigger
end

function M:filter(entity)
    return entity:has(Components.CommandCreate)
end

function M:execute()
    local cmd = self.input_entity:get(Components.CommandCreate)
    --print("create mover", cmd.id)
    local mover = self.context:create_entity()
    local x = math.random(self.cfg.min_random_edge, self.cfg.max_random_edge)
    local y = math.random(self.cfg.min_random_edge, self.cfg.max_random_edge)
    local speed = self.cfg.speed
    local raduis = self.cfg.raduis

    local spriteid = math.random(1,6)

    local vec = vector2.new(x,y)
    vec:normalize()

    mover:add(Components.Position, x, y)
    mover:add(Components.Direction,vec.x, vec.y)
    mover:add(Components.BaseData, cmd.id, cmd.data.name,spriteid)
    mover:add(Components.Speed, speed)
    mover:add(Components.Radius, raduis)
    mover:add(Components.Mover)

    self.net.send(cmd.id, "S2CEnterRoom",{id=cmd.id})
    self.net.send_component(cmd.id,mover,Components.Mover)
    self.net.send_component(cmd.id,mover,Components.BaseData)
    self.net.send_component(cmd.id,mover,Components.Position)
    self.net.send_component(cmd.id,mover,Components.Direction)
    self.net.send_component(cmd.id,mover,Components.Speed)
    self.net.send_component(cmd.id,mover,Components.Radius)

    self.aoi.update_message()--触发周围的玩家、Food进入视野
end

return M
