
local M = {}

local map_fd = {}
local map_players = {}

function M.set(fd, playerid)
    assert(not map_fd[fd])
    assert(not map_players[playerid])
    local conn = {
        fd = fd,
        playerid = playerid,
        roomid = 0
    }

    map_fd[fd] = conn
    map_players[playerid] = conn
end

function M.set_roomid(playerid, roomid)
    local conn = map_players[playerid]
    if conn then
        conn.roomid = roomid
    end
end

function M.remove( fd )
    local conn = map_fd[fd]
    if conn then
        map_fd[fd] = nil
        map_players[conn.playerid] = nil
    end
end

function M.remove_by_player( playerid )
    local conn = map_players[playerid]
    if conn then
        map_fd[conn.fd] = nil
        map_players[playerid] = nil
    end
end

function M.find( fd )
    return  map_fd[fd]
end

function M.find_by_player( playerid )
    return  map_players[playerid]
end

return M