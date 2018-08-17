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

function M:get_trigger()
    return {
        {
            Matcher({Components.CommandCreate}),
            GroupEvent.ADDED | GroupEvent.UPDATE
        }
    }
end

function M:filter(entity)
    return entity:has(Components.CommandCreate)
end

function M:execute()
    local cmd = self.input_entity:get(Components.CommandCreate)
    print("create mover", cmd.id)
    local mover = self.context:create_entity()
    local x = math.random(self.cfg.min_random_edge, self.cfg.max_random_edge)
    local y = math.random(self.cfg.min_random_edge, self.cfg.max_random_edge)
    local dir = math.random(0,360)
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
    self.aoi.add(cmd.id)
    self.aoi.update_message()

    self.net.send(cmd.id, "S2CEnterView", {id = cmd.id})
    self.net.send_component(cmd.id,mover,Components.Mover)
    self.net.send_component(cmd.id,mover,Components.BaseData)
    self.net.send_component(cmd.id,mover,Components.Position)
    self.net.send_component(cmd.id,mover,Components.Direction)
    self.net.send_component(cmd.id,mover,Components.Speed)
    self.net.send_component(cmd.id,mover,Components.Radius)

end

return M
