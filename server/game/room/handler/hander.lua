local moon = require("moon")
local aoi = require("room.aoi")
local vector2 = require("common.vector2")
local Components = require("room.Components")

---@type room_context
local context = ...

local conf = context.conf

local ecs_context = context.ecs_context

local uid_index = context.uid_index

local vec = vector2.new(0,0)

local CMD = {}

function CMD.SetAddress(uid, address)
    context.uid_address[uid] = address
    return true
end

function CMD.C2SEnterRoom(uid, req)
	local mover = ecs_context:create_entity()
    local x = math.random(conf.map.x, conf.map.x + conf.map.len)
    local y = math.random(conf.map.y, conf.map.y + conf.map.len)
    local speed = conf.speed
    local raduis = conf.raduis

    local spriteid = math.random(1,6)

	vec:set_x(x)
	vec:set_y(y)
    vec:normalize()

    print("ROOM: enter", uid)


    mover:add(Components.Position, x, y)
    mover:add(Components.Direction,vec.x, vec.y)
    mover:add(Components.BaseData, uid, req.username, spriteid)
    mover:add(Components.Speed, speed)
    mover:add(Components.Radius, raduis)
    mover:add(Components.Mover)
    mover:add(Components.Score,0)

    context.send(uid, "S2CEnterRoom",{id=uid})
    context.send_component(uid,mover,Components.Mover)
    context.send_component(uid,mover,Components.Position)
    context.send_component(uid,mover,Components.Direction)
    context.send_component(uid,mover,Components.Speed)
    context.send_component(uid,mover,Components.Radius)
    context.send_component(uid,mover,Components.BaseData)

    aoi.insert(uid, x, y, true)
end

-- call by agent 玩家离开房间，
function CMD.LeaveRoom(uid)
    local e = uid_index:get_entity(uid)
    if e then
        aoi.erase(uid,true)
        ecs_context:destroy_entity(e)
        context.uid_address[uid] = nil
        print("ROOM: leave", uid)
    end
end

function CMD.CreateFood(count)
	for _ = 1, count do
        local food = ecs_context:create_entity()
        local x = math.random(conf.map.x, conf.map.x + conf.map.len)
        local y = math.random(conf.map.y, conf.map.y + conf.map.len)
        local spriteid = math.random(1,12)
        food:add(Components.Position, x, y)
        food:add(Components.BaseData, context.fooduid, "",spriteid)
        food:add(Components.Food)
        food:add(Components.Radius, conf.food_raduis)
        aoi.insert(context.fooduid, x, y)
        context.fooduid = context.fooduid + 1
    end
end

function CMD.CommandMove(uid, req)
    local e = uid_index:get_entity(uid)
    if not e then
        print("command move: Mover not found ", uid)
        return
    end
    vec:set_x(req.x)
    vec:set_y(req.y)
    vec:normalize()
    e:replace(Components.Direction,vec.x,vec.y)
    --print("CommandMove",vec.x,vec.y)
end

local entitas = require("entitas")
local Matcher = entitas.Matcher

function CMD.GameOver()
    local movers = context.ecs_context:get_group(Matcher({Components.Mover})).entities
    movers:foreach(function(e)
        local BaseData = e:get(Components.BaseData)
        local score = e:get(Components.Score).score
        local address = context.uid_address[BaseData.id]
        if address then
            moon.send("lua",address,nil, "GameOver", score)
        end
    end)
    moon.quit()
end

return CMD