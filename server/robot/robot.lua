local moon = require("moon")
local json = require("json")
local socket = require("moon.socket")
local MSGID = require("game.MSGID")
local vector2 = require("game.logic.vector2")

local username = 1

local config

local function session_read( session )
    local data,err = session:co_read(2)
    if not data then
        print(session.connid,"session read error")
        return false
    end

    local len = string.unpack(">H",data)

    data,err = session:co_read(len)
    if not data then
        print(session.connid,"session read error")
        return false
    end
    local id = string.unpack("<H",string.sub(data,1,2))
    return id,json.decode(string.sub(data,3))
end

local function send(session,data)
    local len = #data
    return session:send(string.pack(">H",len)..data)
end

local create_user

local function session_hander( session,bauth,authdata)
    if bauth then
        username = username + 1
        local c2slogin = MSGID.encode(MSGID.C2SLogin,{username = "user"..tostring(username)})
        send(session,c2slogin)

        local id,data = session_read(session)
        if not id then
            return
        end
        authdata = data
    end

    local c2s_enterroom = MSGID.encode(MSGID.C2SEnterRoom,{username = authdata.username})
    if not c2s_enterroom then
        return
    end
    send(session,c2s_enterroom)

    local timerid = moon.repeated(3000,-1,function ( trid )
        local vec2 = vector2.new(0,0)
        local x = math.random(-10, 10)
        local y = math.random(-10, 10)
        vec2:set_x(x)
        vec2:set_y(y)
        vec2:normalize()
        local c2s_move = MSGID.encode(MSGID.C2SCommandMove,{x = vec2.x,y=vec2.y})
        if not c2s_move then
            print("error")
            moon.remove_timer(trid)
            return
        end

        if not send(session,c2s_move) then
            return
        end
    end)

    while true do
        local _,data = session_read(session)
        if not _ then
            print("close",_)
            return
        end

        if _ == MSGID.S2CLeaveView and authdata.uid == data.id then
            print("LeaveView")
            moon.remove_timer(timerid)
            session_hander(session,false,authdata)
            return
        end
    end
end

moon.init(function (cfg )
    config = cfg
    return true
end)

moon.start(function()

    local sock = socket.new()

    create_user = function ()
        local session = sock:co_connect(config.ip,config.port)
        moon.async(function ()
            session_hander(session,true)
        end)
    end


    moon.async(function(  )
        for _=1,config.num do
            create_user()
        end
    end)
end)

