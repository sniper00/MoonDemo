local moon = require("moon")
local log = require("log")
local seri = require("seri")
local connects = require("connects")
local MSGID = require("MSGID")

local network = moon.get_tcp("network")

local socket_handler = {}

local login_service -- login 服务id
local match_service -- 匹配服务id(暂时没有实现)
local game_service

-- enum class socket_data_type :std::uint8_t
-- {
--     socket_connect = 1,
--     socket_accept =2,
--     socket_recv = 3,
--     socket_close =4,
--     socket_error = 5,
--     socket_logic_error = 6
-- };

socket_handler[1] = function(sessionid, msg)
	print("connect ",sessionid,msg:bytes())
end

socket_handler[2] = function(sessionid, msg)
	print("accept ",sessionid,msg:bytes())
end

socket_handler[3] = function(sessionid, msg)
    if msg:size() < 2 then
        -- 消息数据非法，没有消息ID
        network:close(sessionid)
        return
    end

    -- 协议结构
    -- 2Byte(msgid)+data
    -- 获取消息ID
    local id = string.unpack("<H",msg:substr(0,2))

    local conn = connects.find(sessionid)
    if not conn then --玩家没有login
        --玩家必须先login
        if id&0xFF00 ~= 0x0100 then
            log.warn("CLIENT %u SEND invalid message %d, will close. not login",sessionid,id)
            network:close(sessionid)
            return
        end

        local ctx = seri.packstring("login",sessionid)
        --登陆流程step1 转发给login service
        msg:redirect(ctx,login_service,moon.PLUA)
        return
    end

    local ctx = seri.packstring("C2S",conn.playerid)

    if(id&0xFF00) == 0x0200 then
        -- 转发给match service
        msg:redirect(ctx,match_service,moon.PLUA)
        return
    elseif (id&0xFF00) == 0x0300 then
        -- 转发给玩家所在房间 service
        msg:redirect(ctx,game_service,moon.PLUA)
        return
    end

    --收到非法数据
	log.warn("CLIENT %u SEND invalid message %d, will close.",sessionid,id)
    network:close(sessionid)
end

socket_handler[4] = function(sessionid, msg)
    print("close ",sessionid, msg:bytes())

    local conn = connects.find(sessionid)
    if not conn then
        return
    end

    local ctx = seri.packstring("client_close",conn.playerid)

    moon.send('lua', login_service,ctx,"")
    --moon.send('lua', match_service,ctx,"")

    moon.send('lua', game_service,ctx,"")

    connects.remove(sessionid)
end

socket_handler[5] = function(sessionid, msg)
	print("error ",sessionid, msg:bytes())
end

socket_handler[6] = function(sessionid, msg)
	print("logic error ",sessionid, msg:bytes())
end

-----------------服务间消息处理-------------------
local command = {}

-- 发送给客户端的消息
command.S2C = function(playerid, msg)
    local conn = connects.find_by_player(playerid)
    if not conn then
        return
    end
    network:send_message(conn.sessionid,msg)
end

-- 登陆流程step3，gate 保存playerid-sessionid 映射
command.login_res = function(_, msg)
    local data = seri.unpack(msg:bytes())
    if data.ret == "OK" then
        connects.set(data.sessionid,data.playerid)
    else
        log.warn("session %d login failed %s",data.sessionid, data.ret)
    end

    -- 登陆结果返回给客户端
    local S2CLogin ={
        ret = data.ret,
        playerid = data.playerid
    }

    network:send(data.sessionid, MSGID.encode(MSGID.S2CLogin,S2CLogin))
end

-- command.set_room_id = function(playerid, msg)
--     local conn = connects.find_by_player(playerid)
--     if not conn then
--         log.warn("set_room_id: player %s not connect",playerid);
--         return
--     end
--     local roomid = seri.unpack(msg:bytes())
--     connects.set_roomid(playerid,roomid)
-- end

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

    login_service = moon.unique_service("login")
    match_service = moon.unique_service("match")
    game_service = moon.unique_service("game")

	moon.register_protocol(
	{
		name = "socket",
		PTYPE = moon.PSOCKET,
		pack = function(...) return ... end,
		dispatch = function(msg)
			local sessionid = msg:sender()
			local subtype = msg:subtype()
			local f = socket_handler[subtype]
			if f then
				f(sessionid, msg)
			end
		end
    })

    moon.dispatch('lua',function(msg,p)
		local sender = msg:sender()
        local header = msg:header()
        docmd(sender, header, msg)
    end)
end)


