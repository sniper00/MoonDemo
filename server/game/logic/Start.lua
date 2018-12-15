--  Bring your systems together
local require = require("import")

local entitas    = require('entitas')
local Components = require('Components')
local NetworkInputSystem = require('NetworkInputSystem')
local CreateMoverSystem = require('CreateMoverSystem')
local RemoveMoverSystem = require('RemoveMoverSystem')
local CommandMoveSystem = require('CommandMoveSystem')
local MoveSystem = require('MoveSystem')
local MapInitSystem = require('MapInitSystem')
local CreateFoodSystem = require('CreateFoodSystem')
local DeadSystem = require('DeadSystem')
local EatSystem = require('EatSystem')
local UpdateDirectionSystem = require('UpdateDirectionSystem')
local UpdateRadiusSystem = require('UpdateRadiusSystem')
local UpdateSpeedSystem = require('UpdateSpeedSystem')

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

--保存contexts.input的唯一entity input_entity,方便使用
contexts.input.input_entity =contexts.input:create_entity()

local systems = Systems.new()

local M = {}

M.init = function ()
    systems:add(NetworkInputSystem.new(contexts,Helper))
    systems:add(MapInitSystem.new(contexts,Helper))
    systems:add(CreateFoodSystem.new(contexts,Helper))
    systems:add(CreateMoverSystem.new(contexts,Helper))
    systems:add(RemoveMoverSystem.new(contexts,Helper))
    systems:add(CommandMoveSystem.new(contexts,Helper))
    systems:add(UpdateDirectionSystem.new(contexts,Helper))
    systems:add(MoveSystem.new(contexts,Helper))
    systems:add(DeadSystem.new(contexts,Helper))
    systems:add(EatSystem.new(contexts,Helper))
    systems:add(UpdateRadiusSystem.new(contexts,Helper))
    systems:add(UpdateSpeedSystem.new(contexts,Helper))

    systems:activate_reactive_systems()
    systems:initialize()
end

M.dispatch = function ( ... )
    systems:dispatch(...)
    systems:execute()
end

M.destroy = function ()
    systems:cleanup()
    systems:clear_reactive_systems()
    systems:tear_down()
end


local function print_table_size(t)
    local result = {}
    local maxtable = {}
    local print_one
    print_one = function( _t,key )
        local count = 0
        for k,v in pairs(_t) do
            if type(v) == "table" and k~="__index" then
                print_one(v,key.."."..tostring(k))
            end
            count = count + 1
        end
        -- table.insert(result,key)
        -- table.insert(result," len ")
        -- table.insert(result,tostring(count))
        -- table.insert(result,"\n")
        table.insert(maxtable,{key=key,count =count})
    end
    print_one(t,"ROOT")

    table.sort(maxtable, function(a,b) return a.count>b.count end )

    return table.concat(result),maxtable
end

M.printinfo = function(  )
    print("context game entitas size:",contexts.game:entity_size())
    print("context game entity_pool size:",#contexts.game._entities_pool)
    print("helper aoi cache size:",Helper.aoi.cache_size())
    local alltable,maxtable = print_table_size(contexts.game)
    local cache = {}
    for i=1,20 do
        local t = maxtable[i]
        table.insert(cache,"####")
        table.insert(cache,t.key)
        table.insert(cache,"####")
        table.insert(cache," [")
        table.insert(cache,tostring(t.count))
        table.insert(cache,"]")
        table.insert(cache,"\n")
    end
    print(table.concat(cache))
end

return M

