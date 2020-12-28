local moon = require("moon")
local vector2 = require("common.vector2")
local constant = require("common.constant")

---@type room_context
local context = ...

local conf = context.conf

local MemModel = {
    players = {},
    foods = {}
}

---@class RoomModel
local RoomModel = {}

function RoomModel.FindPlayer(uid)
    return MemModel.players[uid]
end

function RoomModel.CreatePlayer(uid, req)
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

function RoomModel.FindFood(uid)
    return MemModel.foods[uid]
end

function RoomModel.CreateFood()
    local food = {}
    food.id = constant.MakeUUID(constant.Type.Food)
    food.x = math.random(conf.map.x, conf.map.x + conf.map.size)
    food.y = math.random(conf.map.y, conf.map.y + conf.map.size)
    food.radius = conf.food_radius
    food.spriteid = math.random(1,12)
    MemModel.foods[food.id] = food
    return food
end

function RoomModel.RemoveFood(id)
    MemModel.foods[id] = nil
end

function RoomModel.RemovePlayer(uid)
    return MemModel.players[uid]
end

function RoomModel.UpdateDir(uid, req)
    local player = MemModel.players[uid]
    player.dir.x = req.x
    player.dir.y = req.y
    player.movetime = moon.now()
    vector2.normalize(player.dir)
    -- print(player.dir.x, player.dir.y)
    return player
end

function RoomModel.GetAllPlayer()
    return MemModel.players
end

return RoomModel