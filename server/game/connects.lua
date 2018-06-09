
local M = {}

local map_sessions = {}
local map_players = {}

function M.set(sessionid, playerid)
    assert(not map_sessions[sessionid])
    assert(not map_players[playerid])
    local conn = {
        sessionid = sessionid,
        playerid = playerid,
        roomid = 0
    }

    map_sessions[sessionid] = conn
    map_players[playerid] = conn
end

function M.set_roomid(playerid, roomid)
    local conn = map_players[playerid]
    if conn then
        conn.roomid = roomid
    end
end

function M.remove( sessionid )
    local conn = map_sessions[sessionid]
    if conn then
        map_sessions[sessionid] = nil
        map_players[conn.playerid] = nil
    end
end

function M.remove_by_player( playerid )
    local conn = map_players[playerid]
    if conn then
        map_sessions[conn.sessionid] = nil
        map_players[playerid] = nil
    end
end

function M.find( sessionid )
    return  map_sessions[sessionid]
end

function M.find_by_player( playerid )
    return  map_players[playerid]
end

return M