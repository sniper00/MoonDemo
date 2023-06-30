local moon = require("moon")
local seri = require("seri")
local uuid = require("uuid")
local common = require("common")

local protocol = common.protocol_pb
local vector2 = common.vector2
local GameDef = common.GameDef
local CmdCode = common.CmdCode
local GameCfg = common.GameCfg

---@type room_context
local context = ...

local scripts = context.scripts

local conf = context.conf

local MemModel = {
    players = {},
    foods = {},
    roomid = 0,
}

---@class Room
local Room = {}

function Room.Init(roomid)
    MemModel.roomid = roomid

    moon.timeout(GameCfg.constant.room.round_time * 1000, function()
        Room.GameOver()
    end)

    scripts.Aoi.init_map(conf.map.x, conf.map.y, conf.map.size)
    for i=1,500 do
        local food = Room.CreateFood()
        scripts.Aoi.insert(food.id, food.x, food.y, 0, false)
    end

    moon.async(function()
        while true do
            moon.sleep(100)
            Room.Update()
        end
    end)

    return true
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
    food.id = uuid.next(GameDef.TypeFood)
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
    context.S2C(uid, CmdCode.S2CEnterRoom, {id = uid, time = moon.now()})
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

    scripts.Aoi.fireEvent(uid, GameDef.AoiEvent.UpdateDir, function(watchers)
        moon.raw_send("S2C", context.addr_gate, protocol.encode(watchers, CmdCode.S2CMove,{
            id = uid,
            x = player.x,
            y = player.y,
            dirx = player.dir.x,
            diry = player.dir.y,
            movetime = player.movetime
            }
            ), 0)
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
                if uuid.isuid(id) then
                    entity = Room.FindPlayer(id)
                else
                    entity = Room.FindFood(id)
                end

                assert(entity, tostring(id))

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
                scripts.Aoi.fireEvent(player.id, GameDef.AoiEvent.UpdateRadius, function(watchers)
                    moon.raw_send("S2C", context.addr_gate, protocol.encode(watchers, CmdCode.S2CUpdateRadius,{
                        id = player.id,
                        radius = player.radius
                        }
                    ), 0)
                end)
            end
        end
    end

    local deadcount = #dead

    for _,id in ipairs(dead) do
        scripts.Aoi.erase(id)
        if uuid.isuid(id) then
            context.S2C(id, "S2CDead",{id=id})
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
    moon.send("lua", context.addr_center, "Center.RemoveRoom", moon.id)
    moon.quit()
end

return Room