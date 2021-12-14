local moon = require("moon")
local json = require("json")
local socket = require("moon.socket")
local MSGID = require("common.cmdcode")
local msgutil = require("common.protocol")
local vector2 = require("common.vector2")

local conf = ...

local function client_read( fd )
    assert(fd)
    local data,err = socket.read(fd, 2)
    if not data then
        return false, err
    end
    local len = string.unpack(">H",data)
    data,err = socket.read(fd, len)
    if not data then
        return false, err
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

--游戏逻辑流程
local function client_handler( fd, uname)
    ---auth message
    send(fd, msgutil.encode(MSGID.C2SLogin, {openid = uname}))

    local _,data = client_read(fd)
    assert(data.ok == true,data)
    -- print_r(data)

    --请求匹配
    local C2SMatch = msgutil.encode(MSGID.C2SMatch)
    send(fd,C2SMatch)

    local _,data = client_read(fd)
    assert(data.res, "C2SMatch failed")
    -- print_r(data)

    --等待匹配成功
    repeat
        local id = client_read(fd)
    until id == MSGID.S2CMatchSuccess

    print("robot", uname ," match success")

    --请求进入房间
    local c2s_enterroom = msgutil.encode(MSGID.C2SEnterRoom,{name = uname})
    if not c2s_enterroom then
        print("MSGID.C2SEnterRoom encode error")
        return
    end
    send(fd,c2s_enterroom)

    local _,data = client_read(fd)
    assert(_ == MSGID.S2CEnterRoom, "C2SEnterRoom failed")

    print("robot", uname ," enter room success")

    --进入房间成功后，模拟随机移动
    local exit = false
    moon.async(function()
        while true do
            moon.sleep(3000)
            if exit then
                break
            end
            local dir = {x = math.random(-10, 10), y = math.random(-10, 10)}
            vector2.normalize(dir)
            local c2s_move = msgutil.encode(MSGID.C2SMove, dir)
            if not c2s_move then
                print("MSGID.C2SCommandMove encode error")
                return
            end
            assert(send(fd, c2s_move))
            --print("C2SCommandMove", uname, dir.x, dir.y)
        end
    end)

    while true do
        local _,err = client_read(fd)
        if not _ then
            exit = true
            return
        end

        if _ == MSGID.S2CDead then
            print("ROBOT DEAD: ", uname)
            exit = true
            return
        elseif _ == MSGID.S2CGameOver then
            print("GAME OVER: ", uname)
            exit = true
            return
        end
    end
end

moon.async(function()
    moon.sleep(10)
    local username = 0

    local create_user
    create_user = function (un)
        if not un then
            username = username + 1
            un = username
        end

        local fd, err = socket.connect(conf.host, conf.port, moon.PTYPE_TEXT)
        if not fd then
            print("connect game server failed", err)
            return
        end

        moon.async(function ()
            print(xpcall(client_handler, debug.traceback, fd, "robot"..tostring(un)))
            socket.close(fd)
            moon.sleep(20)
            --create_user(un)
        end)
    end

    moon.sleep(3000)
    for _=1,conf.num do
        create_user()
        moon.sleep(10)
    end
end)



