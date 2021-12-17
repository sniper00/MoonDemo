local moon = require("moon")
local seri = require("seri")
local vector2 = require("common.vector2")
local constant = require("common.constant")
local cmdcode = require("common.cmdcode")
local protocol= require("common.protocol")

---@type room_context
local context = ...

local scripts = context.scripts

local conf = context.conf

local MemModel = {
    players = {},
    foods = {}
}

---@class Room
local Room = {}

function Room.Init()
    -- body
    scripts.Aoi.init_map(conf.map.x, conf.map.y, conf.map.size)

    for i=1,500 do
        local food = Room.CreateFood()
        scripts.Aoi.insert(food.id, food.x, food.y, 0, false)
    end
end

function Room.FindPlayer(uid)
    return MemModel.players[uid]
end

function Room.CreatePlayer(uid, req)
    local p = {id = uid, name = req.name, score = 0}
    p.x = math.random(conf.map.x, conf.map.x + conf.map.size)
    p.y = math.random(conf.map.y, conf.map.y + conf.map.size)

    p.dir = {x = p.x, y = p.y}

    vector2.normalize(p.dir)

    p.speed = conf.speed
    p.radius = conf.radius
    p.spriteid = math.random(1,6)
    p.movetime = moon.now()
    MemModel.players[uid] = p

    return p
end

function Room.FindFood(uid)
    return MemModel.foods[uid]
end

function Room.CreateFood()
    local food = {}
    food.id = constant.MakeUUID(constant.Type.Food)
    food.x = math.random(conf.map.x, conf.map.x + conf.map.size)
    food.y = math.random(conf.map.y, conf.map.y + conf.map.size)
    food.radius = conf.food_radius
    food.spriteid = math.random(1,12)
    MemModel.foods[food.id] = food
    return food
end

function Room.RemoveFood(id)
    MemModel.foods[id] = nil
end

function Room.RemovePlayer(uid)
    return MemModel.players[uid]
end

function Room.UpdateDir(uid, req)
    local player = MemModel.players[uid]
    player.dir.x = req.x
    player.dir.y = req.y
    player.movetime = moon.now()
    vector2.normalize(player.dir)
    -- print(player.dir.x, player.dir.y)
    return player
end

function Room.GetAllPlayer()
    return MemModel.players
end

function Room.C2SEnterRoom(uid, req)
    context.send(uid, cmdcode.S2CEnterRoom, {id = uid, time = moon.now()})
    local player = Room.FindPlayer(uid)
    if not player then
        player = Room.CreatePlayer(uid, req)
    end
    scripts.Aoi.enter(uid, uid)
    scripts.Aoi.insert(player.id, player.x, player.y, 20, true)
end

function Room.UpdatePos(player)
    local now = moon.now()
    local delta = (now - player.movetime)/1000
    player.movetime = now

    local dir = player.dir
    local addpos = vector2.mul(dir, player.speed * delta)
    local x, x_isover = math.clamp(player.x + addpos.x, conf.map.x, conf.map.x + conf.map.size)
    local y, y_isover = math.clamp(player.y + addpos.y, conf.map.y, conf.map.y + conf.map.size)

    if x_isover then player.dir.x = 0.0 end
    if y_isover then player.dir.y = 0.0 end

    if x_isover or y_isover then
        vector2.normalize(player.dir)
    end

    player.x = x
    player.y = y

    --print(player.x, player.y, x, y, player.dir.x, player.dir.y)

    return x_isover or y_isover
end

function Room.C2SMove(uid, req)
    -- local p = RoomModel.FindPlayer(uid)
    -- local mt = p.movetime
    Room.UpdatePos(Room.FindPlayer(uid))
    --print(moon.now(), mt, p.x, p.y)
    local player = Room.UpdateDir(uid, req)
    local prefabid = moon.make_prefab(protocol.encode(cmdcode.S2CMove,{
        id = uid,
        x = player.x,
        y = player.y,
        dirx = player.dir.x,
        diry = player.dir.y,
        movetime = player.movetime
        }
    ))
    scripts.Aoi.fireEvent(uid, constant.AoiEvent.UpdateDir, function(watcher)
        moon.send_prefab(context.addr_gate, prefabid, seri.packs(watcher), 0, constant.PTYPE_TOCLIENT)
    end)
end

function Room.LeaveRoom(uid)
    Room.RemovePlayer(uid)
    scripts.Aoi.erase(uid)
    print("LeaveRoom", uid)
end

function Room.Update()
    local players = Room.GetAllPlayer()
    for _, player in pairs(players) do
        local over = Room.UpdatePos(player)
        if over then
            Room.C2SMove(player.id, player.dir)
        end
        scripts.Aoi.update(player.id, player.x, player.y, 20)
    end

    local dead = {}
    for _, player in pairs(players) do
        if not player.dead then
            local radius = player.radius
            local res = scripts.Aoi.query(player.x, player.y, player.radius, player.radius)
            for _, id in ipairs(res) do
                local entity
                if constant.IsPlayer(id) then
                    entity = Room.FindPlayer(id)
                else
                    entity = Room.FindFood(id)
                end

                if not entity.dead then
                    local distance = math.sqrt((player.x - entity.x)^2 + (player.y - entity.y)^2 )
                    if distance < (player.radius + entity.radius) then
                        if player.radius > entity.radius then
                            entity.dead = true
                            table.insert(dead, id)
                            player.score = player.score + 1
                            player.radius = player.radius + 0.1
                            if player.radius > 5 then
                                player.radius = 0.3
                                --print("radius too big")
                            end
                        end
                    end
                end
            end

            if player.radius ~= radius then
                local prefabid = moon.make_prefab(protocol.encode(cmdcode.S2CUpdateRadius,{
                    id = player.id,
                    radius = player.radius
                    }
                ))
                scripts.Aoi.fireEvent(player.id, constant.AoiEvent.UpdateRadius, function(watcher)
                    moon.send_prefab(context.addr_gate, prefabid, seri.packs(watcher), 0, constant.PTYPE_TOCLIENT)
                end)
            end
        end
    end

    local deadcount = #dead

    for _,id in ipairs(dead) do
        scripts.Aoi.erase(id)
        if constant.IsPlayer(id) then
            context.send(id,"S2CDead",{id=id})
            Room.RemovePlayer(id)
        else
            Room.RemoveFood(id)
        end
    end

    if deadcount > 0 then
        for i=1,deadcount do
            local food = Room.CreateFood()
            scripts.Aoi.insert(food.id, food.x, food.y, 0, false)
        end
    end
end

---called by timer
function Room.GameOver()
    local players = Room.GetAllPlayer()
    for _, player in pairs(players) do
        context.send_user(player.id, "User.GameOver", player.score)
    end
    moon.send("lua", context.addr_center, "Center.RemoveRoom", moon.addr())
    moon.quit()
end

return Room