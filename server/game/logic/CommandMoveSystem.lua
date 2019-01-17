local require = require("import")
local class = class or require("base.class")
local entitas    = require('entitas')
local Components = require('Components')
local vector2 = require("vector2")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher    = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local M = class("CommandMoveSystem",ReactiveSystem)

function M:ctor(contexts,helper)
    M.super.ctor(self,contexts.input)
    self.idx = contexts.idx
    self.net = helper.net
    self.movers = contexts.game:get_group(Matcher({Components.Mover}))
    self.input_entity = contexts.input.input_entity
end

local trigger = {
    {
        Matcher({Components.CommandMove}),
        GroupEvent.ADDED|GroupEvent.UPDATE
    }
}

function M:get_trigger()
    return trigger
end

function M:filter(entity)
    return entity:has(Components.CommandMove)
end

local vec = vector2.new()
-- Net entites
function M:execute()
    local cmd = self.input_entity:get(Components.CommandMove)
    local ety = self.idx:get_entity(cmd.id)
    if not ety then
        print("command move not found ", cmd.id)
        --self.net.close(cmd.id)
        return
    end
    vec:set_x(cmd.data.x)
    vec:set_y(cmd.data.y)
    vec:normalize()
    ety:replace(Components.Direction,vec.x,vec.y)
    --print("CommandMove",vec.x,vec.y)
end

return M
