local moon = require("moon")
---@type center_context
local context = ...

local conf = context.conf

local room_conf = {
    name="room",
    file="game/room.lua",
    map ={
        x = -64,
        y = -64,
        len = 128
    },
    speed = 2,
    raduis = 0.3,
    food_raduis = 0.25,
}

local room_name = room_conf.name

local room_inrc_id = 1

--简单的匹配策略
local function CheckMatchQueue(q)
    if #q >= conf.max_room_player_number then
        room_conf.name = room_name..room_inrc_id
        room_conf.time = conf.time
        room_inrc_id = room_inrc_id + 1
        local room = moon.co_new_service("lua", room_conf)
        local n = 0
        while n<conf.max_room_player_number do
            local uid = table.remove(q,1)
            local p = context.match_map[uid]
            if p then
                -- use send,because client may disconnected
                moon.send("lua", p.address, nil, "MatchSuccess", room)
                context.match_map[uid] = nil
            end
            n = n + 1
        end
    end
end

local CMD = {}

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

return CMD