local moon = require("moon")
local seri = require("seri")
local setup = require("common.setup")
local msgutil = require("common.msgutil")
local constant = require("common.constant")
local entitas    = require("entitas")
local Components = require("room.Components")
local aoi = require("room.aoi")
local MoveSystem = require('room.system.MoveSystem')
local DeadSystem = require('room.system.DeadSystem')
local EatSystem = require('room.system.EatSystem')
local UpdateDirectionSystem = require('room.system.UpdateDirectionSystem')
local UpdateRadiusSystem = require('room.system.UpdateRadiusSystem')
local UpdateSpeedSystem = require('room.system.UpdateSpeedSystem')

local conf = ...

aoi.create(conf.map.x, conf.map.y, conf.map.len, 8)

local mdecode = msgutil.decode

local PTOCLIENT = constant.PTYPE.TO_CLIENT

local ECSContext = entitas.Context
local Systems = entitas.Systems
local Matcher = entitas.Matcher
local PrimaryEntityIndex = entitas.PrimaryEntityIndex

local ecs_context = ECSContext.new()
local group = ecs_context:get_group(Matcher({Components.BaseData}))
local uid_index = PrimaryEntityIndex.new(Components.BaseData, group, 'id')
ecs_context:add_entity_index(uid_index)


---@class room_context
local context ={
    conf = conf,
    ecs_context = ecs_context,
    uid_index = uid_index,
    docmd = false,
    fooduid = 1000000,
    uid_address = {}
}

local systems = Systems.new()
systems:add(UpdateDirectionSystem.new(context))
systems:add(MoveSystem.new(context))
systems:add(DeadSystem.new(context))
systems:add(EatSystem.new(context))
systems:add(UpdateRadiusSystem.new(context))
systems:add(UpdateSpeedSystem.new(context))

systems:activate_reactive_systems()
systems:initialize()

moon.repeated(50,-1,function()
    systems:update(0.05)
    systems:execute()
end)

context.send = function(uid, msgid, mdata)
    moon.raw_send('toclient', context.gate, seri.packs(uid), msgutil.encode(msgid,mdata))
end

local tcomp = {id = 0,data=nil}
context.send_component = function(uid, entity, comp)
    if entity:has(comp) then
        tcomp.id = entity:get(Components.BaseData).id
        tcomp.data = entity:get(comp)
        moon.raw_send('toclient', context.gate,seri.packs(uid), msgutil.encode(Components.GetID(comp),tcomp))
    end
end

context.make_prefab =function(entity, comp)
    tcomp.id = entity:get(Components.BaseData).id
    tcomp.data = entity:get(comp)
    return moon.make_prefab(msgutil.encode(Components.GetID(comp),tcomp))
end

context.send_prefab =function(uid, prefabid)
    moon.send_prefab(context.gate,prefabid,seri.packs(uid),0,PTOCLIENT)
end

local docmd, command = setup(context,"room")
context.docmd = docmd

moon.dispatch("client",function(msg)
    local uid = seri.unpack(msg:header())
    local cmd, data = mdecode(msg)
    local f = command[cmd]
    if f then
        f(uid, data)
        systems:execute()
    else
        error(string.format("room: PTYPE_CLIENT receive unknown cmd %s. uid %u", tostring(cmd), uid))
    end
end)

moon.start(function()
    context.gate = moon.queryservice("gate")

    context.docmd(0,0,"CreateFood",500)

    --Game Over,结算积分
    moon.repeated(conf.time*6000, 1 , function()
        context.docmd(0,0,"GameOver")
    end)
end)
