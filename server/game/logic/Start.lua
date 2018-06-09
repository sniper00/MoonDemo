--  Bring your systems together

package.path = "../../lualib/?.lua;"..package.path

local entitas    = require('entitas')
local Components = require('Components')
local NetworkInputSystem = require('NetworkInputSystem')
local CreateMoverSystem = require('CreateMoverSystem')
local RemoveMoverSystem = require('RemoveMoverSystem')
local CommandMoveSystem = require('CommandMoveSystem')
local MoveSystem = require('MoveSystem')
local EnterViewSystem = require('EnterViewSystem')
local LeaveViewSystem = require('LeaveViewSystem')
local MapInitSystem = require('MapInitSystem')
local CreateFoodSystem = require('CreateFoodSystem')
local DeadSystem = require('DeadSystem')
local EatSystem = require('EatSystem')

local Helper = require('Helper')

local Context = entitas.Context
local Systems = entitas.Systems
local Matcher = entitas.Matcher
local PrimaryEntityIndex = entitas.PrimaryEntityIndex

local contexts = {
    game = Context.new(),
    input = Context.new()
}

local group = contexts.game:get_group(Matcher({Components.BaseData}))
--保存下来方便不同system 根据id查询对应的 entity
contexts.idx = PrimaryEntityIndex.new(Components.BaseData, group, 'id')
contexts.game:add_entity_index(contexts.idx)

contexts.input.input_entity =contexts.input:create_entity()

local systems = Systems.new()

local M = {}

M.init = function ( ... )
    systems:add(NetworkInputSystem.new(contexts,Helper))
    systems:add(MapInitSystem.new(contexts,Helper))
    systems:add(CreateFoodSystem.new(contexts,Helper))
    systems:add(CreateMoverSystem.new(contexts,Helper))
    systems:add(RemoveMoverSystem.new(contexts,Helper))
    systems:add(CommandMoveSystem.new(contexts,Helper))
    systems:add(MoveSystem.new(contexts,Helper))
    systems:add(EnterViewSystem.new(contexts,Helper))
    systems:add(LeaveViewSystem.new(contexts,Helper))
    systems:add(DeadSystem.new(contexts,Helper))
    systems:add(EatSystem.new(contexts,Helper))
    
    systems:activate_reactive_systems()
    systems:initialize()
end

M.dispatch = function ( ... )
    systems:dispatch(...)
    systems:execute()
end

M.destroy = function ( ... )
    systems:cleanup()
    systems:clear_reactive_systems()
    systems:tear_down()
end

return M

