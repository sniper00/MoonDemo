local util       = require("util")
local entitas    = require('entitas')
local Components = require('Components')
local vector2 = require("vector2")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher    = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local class      = util.class

local M = class("CommandMoveSystem",ReactiveSystem)

function M:ctor(contexts,helper)
    M.super.ctor(self,contexts.input)
    self.idx = contexts.idx
    self.net = helper.net
    self.movers = contexts.game:get_group(Matcher({Components.Mover}))
    self.input_entity = contexts.input.input_entity
end

function M:get_trigger()
    return {
        {
            Matcher({Components.CommandMove}),
            GroupEvent.ADDED|GroupEvent.UPDATE
        }
    }
end

function M:filter(entity)
    return entity:has(Components.CommandMove)
end

-- Net entites
function M:execute()
    local cmd = self.input_entity:get(Components.CommandMove)
    local ety = self.idx:get_entity(cmd.id)
    if not ety then
        print("command move not found ", cmd.id)
        return
    end
    local vec = vector2.new(cmd.data.x,cmd.data.y)
    vec:normalize()
    ety:replace(Components.Direction,vec.x,vec.y)
    --print("CommandMove",vec.x,vec.y)
end

return M
