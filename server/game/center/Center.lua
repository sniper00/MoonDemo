local moon = require("moon")
local json = require "json"
local db = require("common.database")
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
    round_time = conf.round_time
}

local room_name = room_conf.name

local room_inrc_id = 1

local rooms = {}

--简单的匹配策略
local function CheckMatchQueue(q)
    if #q >= conf.max_room_player_number then
        room_conf.name = room_name..room_inrc_id
        room_conf.time = conf.time
        room_inrc_id = room_inrc_id + 1
        local addr_room = moon.new_service("lua", room_conf)
        if addr_room == 0 then
            moon.error("create room failed!")
            return
        end
        rooms[addr_room] = true
        local n = 0
        while n<conf.max_room_player_number do
            local uid = table.remove(q,1)
            local p = context.match_map[uid]
            if p then
                context.send_mem_user(uid, "User.MatchSuccess", addr_room)
                context.match_map[uid] = nil
            end
            n = n + 1
        end
    end
end

local CMD = {}

function CMD.Init()
    context.addr_gate = moon.queryservice("gate")
    context.addr_auth = moon.queryservice("auth")
    context.addr_db_server = moon.queryservice("db_server")

    local data = db.loadserverdata(context.addr_db_server)
    if not data then
        data = {boot_times = 0}
    else
        data = json.decode(data)
    end
    data.boot_times = data.boot_times + 1

    assert(db.saveserverdata(context.addr_db_server, json.encode(data)))

    moon.set_env("SERVER_START_TIMES", tostring(data.boot_times))

    return true
end

function CMD.Shutdown()
    for addr_room in pairs(rooms) do
        moon.remove_service(addr_room)
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