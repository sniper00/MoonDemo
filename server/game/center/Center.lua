local moon = require("moon")
local uuid = require("uuid")
local common = require("common")
local GameDef = common.GameDef
local GameCfg = common.GameCfg

---@type center_context
local context = ...

local conf = context.conf

local room_conf = {
    name="room",
    file="game/service_room.lua",
    map ={
        x = -64,
        y = -64,
        size = 128
    },
    speed = 2,
    radius = 0.3,
    food_radius = 0.25,
}

local room_name = room_conf.name

local rooms = {}

--简单的匹配策略
local function CheckMatchQueue(q)
    local max_player_number =  GameCfg.constant.room.max_player_number
    if #q >= max_player_number then
        local roomid = uuid.next(GameDef.TypeRoom)
        room_conf.name = room_name..roomid
        room_conf.time = conf.time
        room_conf.id = roomid
        local addr_room = moon.new_service(room_conf)
        if addr_room == 0 then
            moon.error("create room failed!")
            return
        end
        assert(moon.call("lua", addr_room, "Init", roomid))
        rooms[addr_room] = roomid
        local n = 0
        while n< max_player_number do
            local uid = table.remove(q,1)
            local p = context.match_map[uid]
            if p then
                context.try_send_user(uid, "User.MatchSuccess", addr_room, roomid)
                context.match_map[uid] = nil
            end
            n = n + 1
        end
    end
end

---@class Center
local CMD = {}

function CMD.Shutdown()
    for addr_room in pairs(rooms) do
        moon.kill(addr_room)
    end
    moon.quit()
    return true
end

function CMD.Match(uid, address)
    --print("MATCH", uid, address)
    local v = context.match_map[uid]
    if not v then
        context.match_map[uid] = {address = address}
        table.insert(context.match_queue, uid)
        CheckMatchQueue(context.match_queue)
    end
    return true
end

function CMD.UnMatch(uid)
    context.match_map[uid] = nil
    return true
end

function CMD.RemoveRoom(addr_room)
    rooms[addr_room] = nil
end

return CMD