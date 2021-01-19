local moon = require("moon")
local seri = require("seri")
local constant = require("common.constant")
local msgutil = require("common.msgutil")
local msgcode = require("common.msgcode")
local vector2 = require("common.vector2")

---@type room_context
local context = ...

local conf = context.conf

---@type RoomModel
local RoomModel = context.models.RoomModel

---@type AoiModel
local AoiModel = context.models.AoiModel

local AOI_EVENT = {
    UpdateDir = 10,
    UpdateRadius = 11,
}

local CMD = {}

function CMD.Init()
    -- body
    AoiModel.Init(conf.map.x, conf.map.y, conf.map.size)

    for i=1,500 do
        local food = RoomModel.CreateFood()
        AoiModel.Insert(food.id, food.x, food.y, 0, false)
    end
end

function CMD.C2SEnterRoom(uid, req)
    context.send(uid, msgcode.S2CEnterRoom, {id = uid, time = moon.now()})
    local player = RoomModel.FindPlayer(uid)
    if not player then
        player = RoomModel.CreatePlayer(uid, req)
    end
    CMD.AoiEnter(uid, uid)
    AoiModel.Insert(player.id, player.x, player.y, 20, true)
end

local function UpdatePos(player)
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

function CMD.C2SMove(uid, req)
    -- local p = RoomModel.FindPlayer(uid)
    -- local mt = p.movetime
    UpdatePos(RoomModel.FindPlayer(uid))
    --print(moon.now(), mt, p.x, p.y)
    local player = RoomModel.UpdateDir(uid, req)
    local prefabid = moon.make_prefab(msgutil.encode(msgcode.S2CMove,{
        id = uid,
        x = player.x,
        y = player.y,
        dirx = player.dir.x,
        diry = player.dir.y,
        movetime = player.movetime
        }
    ))
    AoiModel.FireEvent(uid, AOI_EVENT.UpdateDir, function(watcher)
        moon.send_prefab(context.addr_gate, prefabid, seri.packs(watcher), 0, constant.PTYPE.TO_CLIENT)
    end)
end

function CMD.LeaveRoom(uid)
    RoomModel.RemovePlayer(uid)
    AoiModel.Erase(uid)
    print("LeaveRoom", uid)
end

function CMD.Update()
    local players = RoomModel.GetAllPlayer()
    for _, player in pairs(players) do
        local over = UpdatePos(player)
        if over then
            CMD.C2SMove(player.id, player.dir)
        end
        AoiModel.Update(player.id, player.x, player.y, 20)
    end

    local dead = {}
    for _, player in pairs(players) do
        if not player.dead then
            local radius = player.radius
            local res = AoiModel.Query(player.x, player.y, player.radius, player.radius)
            for _, id in ipairs(res) do
                local entity
                if constant.IsPlayer(id) then
                    entity = RoomModel.FindPlayer(id)
                else
                    entity = RoomModel.FindFood(id)
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
                local prefabid = moon.make_prefab(msgutil.encode(msgcode.S2CUpdateRadius,{
                    id = player.id,
                    radius = player.radius
                    }
                ))
                AoiModel.FireEvent(player.id, AOI_EVENT.UpdateRadius, function(watcher)
                    moon.send_prefab(context.addr_gate, prefabid, seri.packs(watcher), 0, constant.PTYPE.TO_CLIENT)
                end)
            end
        end
    end

    local deadcount = #dead

    for _,id in ipairs(dead) do
        AoiModel.Erase(id)
        if constant.IsPlayer(id) then
            context.send(id,"S2CDead",{id=id})
            RoomModel.RemovePlayer(id)
        else
            RoomModel.RemoveFood(id)
        end
    end

    if deadcount > 0 then
        for i=1,deadcount do
            local food = RoomModel.CreateFood()
            AoiModel.Insert(food.id, food.x, food.y, 0, false)
        end
    end
end

---called by timer
function CMD.GameOver()
    local players = RoomModel.GetAllPlayer()
    for _, player in pairs(players) do
        context.send_user(player.id, "GameOver", player.score)
    end
    moon.send("lua", context.addr_center, "RemoveRoom", moon.addr())
    moon.quit()
end

function CMD.AoiEnter(watcher, marker)
    if constant.IsPlayer(marker) then
        context.send(watcher, msgcode.S2CEnterView, RoomModel.FindPlayer(marker))
    else
        context.send(watcher, msgcode.S2CEnterView, RoomModel.FindFood(marker))
    end
end

function CMD.AoiLeave(watcher, marker)
    context.send(watcher, msgcode.S2CLeaveView, {id = marker})
end

return CMD