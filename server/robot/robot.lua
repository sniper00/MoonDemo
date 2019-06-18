local moon = require("moon")
local json = require("json")
local socket = require("moon.socket")
local MSGID = require("game.MSGID")
local vector2 = require("game.logic.vector2")

local username = 1

local config

local function client_read( fd )
    if not fd then
        return false
    end
    local data,err = socket.read(fd, 2)
    if not data then
        print(fd," read error",err)
        return false
    end

    local len = string.unpack(">H",data)

    data,err = socket.read(fd, len)
    if not data then
        print(fd," read error",err)
        return false
    end
    local id = string.unpack("<H",string.sub(data,1,2))
    return id,json.decode(string.sub(data,3))
end

local function send(fd,data)
    if not fd then
        return false
    end
    local len = #data
    return socket.write(fd, string.pack(">H",len)..data)
end

local function client_handler( fd, bauth, authdata)
    if bauth then
        username = username + 1
        local c2slogin = MSGID.encode(MSGID.C2SLogin,{username = "user"..tostring(username)})
        send(fd,c2slogin)

        local id,data = client_read(fd)
        if not id then
            print("client_read error", data)
            return
        end
        authdata = data
    end

    local c2s_enterroom = MSGID.encode(MSGID.CommandCreate,{username = authdata.username})
    if not c2s_enterroom then
        print("MSGID.C2SEnterRoom encode error")
        return
    end
    send(fd,c2s_enterroom)

    local timerid = moon.repeated(3000,-1,function ( trid )
        local vec2 = vector2.new(0,0)
        local x = math.random(-10, 10)
        local y = math.random(-10, 10)
        vec2:set_x(x)
        vec2:set_y(y)
        vec2:normalize()
        local c2s_move = MSGID.encode(MSGID.CommandMove,{x = vec2.x,y=vec2.y})
        if not c2s_move then
            print("MSGID.C2SCommandMove encode error")
            moon.remove_timer(trid)
            return
        end

        if not send(fd,c2s_move) then
            print("send C2SCommandMove encode error")
            moon.remove_timer(trid)
            return
        end

        --print("C2SCommandMove",fd)
    end)

    while true do
        local _,err = client_read(fd)
        if not _ then
            print("close",err)
            moon.remove_timer(timerid)
            return
        end

        if _ == MSGID.S2CDead then
            print("DEAD: ",authdata.uid)
            moon.remove_timer(timerid)
            return fd,false,authdata
        end
    end
end

moon.init(function (cfg )
    config = cfg
    return true
end)

moon.start(function()
    local create_user
    create_user = function ()
        local fd, err = socket.connect(config.host, config.port, moon.PTYPE_TEXT)
        if not fd then
            print("connect failed", err)
            return
        end
        moon.async(function ()
            local ret = {fd,true}
            while true do
                ret = {client_handler(table.unpack(ret))}
                if #ret ==0 then
                    create_user()
                    break
                end
            end
        end)
    end


    moon.async(function(  )
        for _=1,config.num do
            create_user()
            moon.co_wait(10)
        end
    end)

    moon.repeated(10000,-1,function (  )
        collectgarbage("collect")
        print("memory",moon.memory_use())
    end)
end)


