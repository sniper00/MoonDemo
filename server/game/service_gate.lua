local require = require("import")
local moon = require("moon")
local log = require("moon.log")
local socket = require("moon.socket")
local seri = require("seri")
local connects = require("connects")
local MSGID = require("MSGID")

local conf = ...

local login_service -- login 服务id
local match_service -- 匹配服务id(暂时没有实现)
local game_service

local recv_count = 0
local send_count = 0

socket.on("accept",function(fd, msg)
	print("accept ",fd,msg:bytes())
end)

socket.on("message",function(fd, msg)
    if msg:size() < 2 then
        -- 消息数据非法，没有消息ID
        socket.close(fd)
        return
    end

    recv_count = recv_count + 1

    -- 协议结构
    -- 2Byte(msgid)+data
    -- 获取消息ID
    local id = string.unpack("<H",msg:substr(0,2))

    local conn = connects.find(fd)
    if not conn then --玩家没有login
        --玩家必须先login
        if id&0xFF00 ~= 0x0100 then
            log.warn("CLIENT %u SEND invalid message %d, will close. not login",fd,id)
            socket.close(fd)
            return
        end

        local ctx = seri.packs("login",fd)
        --登陆流程step1 转发给login service
        msg:redirect(ctx,login_service,moon.PTYPE_LUA)
        return
    end

    local ctx = seri.packs("C2S",conn.playerid)

    if(id&0xFF00) == 0x0200 then
        -- 转发给match service
        msg:redirect(ctx,match_service,moon.PTYPE_LUA)
        return
    elseif (id&0xFF00) == 0x0300 then
        -- 转发给玩家所在房间 service
        msg:redirect(ctx,game_service,moon.PTYPE_LUA)
        return
    end

    --收到非法数据
	log.warn("CLIENT %u SEND invalid message %d, will close.",fd,id)
    socket.close(fd)
end)

socket.on("close",function(fd, msg)
    print("close ",fd, msg:bytes())

    local conn = connects.find(fd)
    if not conn then
        return
    end

    local ctx = seri.packs("logout",conn.playerid)

    moon.send('lua', login_service,ctx,"")
    --moon.send('lua', match_service,ctx,"")

    moon.send('lua', game_service,ctx,"")

    connects.remove(fd)
end)

socket.on("error",function(fd, msg)
	print("error ",fd, msg:bytes())
end)

-----------------服务间消息处理-------------------
local command = {}

-- 发送给客户端的消息
command.S2C = function(playerid, msg)
    local conn = connects.find_by_player(playerid)
    if not conn then
        return
    end
    send_count = send_count + 1
    socket.write_message(conn.fd,msg)
end

command.logout = function(playerid)
    local conn = connects.find_by_player(playerid)
    if not conn then
        return
    end
    socket.close(conn.fd)
end

-- 登陆流程step3，gate 保存playerid-fd 映射
command.login = function(_, msg)
    local data = seri.unpack(msg:bytes())
    if data.ret == "OK" then
        connects.set(data.fd,data.playerid)
    else
        log.warn("fd %d login failed %s",data.fd, data.ret)
    end

    -- 登陆结果返回给客户端
    local S2CLogin ={
        ret = data.ret,
        uid = data.playerid
    }

    socket.write(data.fd, MSGID.encode(MSGID.S2CLogin,S2CLogin))
end

local function docmd(sender,header,msg)
    local cmd,playerid = seri.unpack(header)
	local f = command[cmd]
	if f then
		f(playerid,msg)
	else
		error(string.format("Unknown command %s", tostring(cmd)))
	end
end
------------------------------------

moon.start(function()
    login_service = moon.queryservice("login")
    match_service = moon.queryservice("match")
    game_service = moon.queryservice("game")

    moon.dispatch('lua',function(msg,p)
        local sender = msg:sender()
        local header = msg:header()
        docmd(sender, header, msg)
    end)

    local listenfd = socket.listen(conf.host,conf.port,moon.PTYPE_SOCKET)
    socket.start(listenfd)

    moon.destroy(function()
        socket.close(listenfd)
    end)
end)



