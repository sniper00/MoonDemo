local util = require("util")
local entitas = require("entitas")
local Components = require("Components")
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
    local x = math.random(-10, 10)
    local y = math.random(-10, 10)
    local dir = math.random(0,360)
    local speed = 2
    local raduis = 0.3
    local spriteid = math.random(1,6)
    mover:add(Components.Position, x, y)
    mover:add(Components.Direction, dir)
    mover:add(Components.BaseData, cmd.id, cmd.data.name,spriteid)
    mover:add(Components.Mover)
    mover:add(Components.Speed, speed)
    mover:add(Components.Radius, raduis)
    self.aoi.add(cmd.id)
    self.aoi.update_message()
    self.net.send(cmd.id, "S2CEnterRoom", {x = x, y = y, dir = dir, speed = speed, radius = raduis})
end

return M
