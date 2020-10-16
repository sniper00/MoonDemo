local moon = require("moon")
local json = require("json")
local crypt = require "crypt"
local socket = require("moon.socket")
local MSGID = require("common.msgcode")
local msgutil = require("common.msgutil")
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

local function login(username)
    local fd = assert(socket.connect(conf.host, conf.login_port, moon.PTYPE_TEXT))

    local function writeline(fd_, text)
        socket.write(fd_, text .. "\n")
    end

    local line,err = socket.readline(fd,"\n")
    if not line then
        error(err)
    end
    local challenge = crypt.base64decode(line)
    local clientkey = crypt.randomkey()
    writeline(fd, crypt.base64encode(crypt.dhexchange(clientkey)))
    local secret = crypt.dhsecret(crypt.base64decode(socket.readline(fd,"\n")), clientkey)

    --print("secret is ", crypt.hexencode(secret))

    local hmac = crypt.hmac64(challenge, secret)
    writeline(fd, crypt.base64encode(hmac))

    local token = {
        server = "game_1",
        user = username,
        pass = "password",
    }

    local function encode_token(token)
        return string.format("%s@%s:%s",
            crypt.base64encode(token.user),
            crypt.base64encode(token.server),
            crypt.base64encode(token.pass))
    end

    local etoken = crypt.desencode(secret, encode_token(token), crypt.padding.pkcs7)
    writeline(fd, crypt.base64encode(etoken))

    local result = socket.readline(fd,"\n")
    --print(result)
    local code = tonumber(string.sub(result, 1, 3))
    --print("robot close socket", fd)
    socket.close(fd)
    assert(code == 200, code)
    local subid = crypt.base64decode(string.sub(result, 5))

    --print("login ok, subid=", subid)

    local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , 1)
    hmac = crypt.hmac64(crypt.hashkey(handshake), secret)
    local handshake_str = handshake .. ":" .. crypt.base64encode(hmac)

    print("ROBOT: login", username)
    return subid,handshake_str
end

--游戏逻辑流程
local function client_handler( fd, subid, handshake ,uname)

    --login 逻辑服务器
    local c2slogin = msgutil.encode(MSGID.C2SLogin,{token = handshake})
    send(fd,c2slogin)

    local _,data = client_read(fd)
    assert(data.res=="200 OK",data)

    --请求匹配
    local C2SMatch = msgutil.encode(MSGID.C2SMatch)
    send(fd,C2SMatch)

    local _,data = client_read(fd)
    assert(data.res, "C2SMatch failed")

    --等待匹配成功
    repeat
        local id = client_read(fd)
    until id == MSGID.S2CMatchSuccess

    --print("robot match success")

    --请求进入房间
    local c2s_enterroom = msgutil.encode(MSGID.C2SEnterRoom,{username = uname})
    if not c2s_enterroom then
        print("MSGID.C2SEnterRoom encode error")
        return
    end
    send(fd,c2s_enterroom)

    local _,data = client_read(fd)
    assert(_ == MSGID.S2CEnterRoom, "C2SEnterRoom failed")

    --进入房间成功后，模拟随机移动
    local timerid = moon.repeated(3000,-1,function ( trid )
        local vec2 = vector2.new(0,0)
        local x = math.random(-10, 10)
        local y = math.random(-10, 10)
        vec2:set_x(x)
        vec2:set_y(y)
        vec2:normalize()
        local c2s_move = msgutil.encode(MSGID.CommandMove,{x = vec2.x,y=vec2.y})
        if not c2s_move then
            print("MSGID.C2SCommandMove encode error")
            moon.remove_timer(trid)
            return
        end
        assert(send(fd,c2s_move))
        --print("C2SCommandMove",fd)
    end)

    while true do
        local _,err = client_read(fd)
        if not _ then
            moon.remove_timer(timerid)
            return
        end

        if _ == MSGID.S2CDead then
            print("ROBOT DEAD: ", subid)
            moon.remove_timer(timerid)
            return
        elseif _ == MSGID.S2CGameOver then
            print("GAME OVER: ", subid)
            moon.remove_timer(timerid)
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

        local ok, subid, handshake = pcall(login,"robot"..tostring(un))
        if not ok then
            print("login failed",subid, handshake)
            return
        end

        local fd, err = socket.connect(conf.host, conf.port, moon.PTYPE_TEXT)
        if not fd then
            print("connect game server failed", err)
            return
        end

        moon.async(function ()
            pcall(client_handler,fd, un, handshake, "robot"..tostring(un))
            socket.close(fd)
            moon.sleep(20)
            create_user(un)
        end)
    end

    moon.sleep(3000)
    for _=1,conf.num do
        create_user()
        moon.sleep(10)
    end
end)



