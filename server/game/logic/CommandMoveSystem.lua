local util       = require("util")
local entitas    = require('entitas')
local Components = require('Components')
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
    ety:replace(Components.Direction,cmd.data.angle)
    local pos = ety:get(Components.Position)
    self.net.send(cmd.id,"S2CCommandMove",{x=pos.x,y=pos.y})
    --print("command move", cmd.id,pos.x,pos.y,cmd.data.angle)

    local movers = self.movers.entities
    movers:foreach(
        function(e)
            local id = e:get(Components.BaseData).id
            if id~= cmd.id then
                self.net.send(id,"S2CCommandMoveB",{id = cmd.id,dir =cmd.data.angle,  x=pos.x,y=pos.y}) 
            end 
        end
    )
end

return M
