local moon = require("moon")
local seri = require("seri")
local json = require("json")
local start = require("Start")
local HelperNet = require("HelperNet")
local Helper = require("Helper")

local command = {}

local function docmd(_,header,msg)
    local cmd,playerid = seri.unpack(header)
	local f = command[cmd]
	if f then
		f(playerid,msg)
	else
		error(string.format("Unknown command %s", tostring(cmd)))
	end
end

--处理客户端发来的消息，包装成input_entity的Component
--来驱动ECS运行
command.C2S = function(playerid, msg)
    local id = string.unpack("<H",msg:substr(0,2))
    start.dispatch(id,playerid,json.decode(msg:substr(2,-1)))
end

command.client_close = function(playerid)
    --参见ComponentsIndex
    start.dispatch(2,playerid)
end

moon.init(function ( cfg )
    Helper.cfg = cfg.game
    return true
end)

moon.start(function()
    HelperNet.set_gate_service(moon.unique_service("gate"))

    moon.dispatch('lua',function(msg,_)
		local sender = msg:sender()
        local header = msg:header()
        docmd(sender, header, msg)
    end)

    start.init()

    --每50ms触发一次CommandUpdate,用来更新玩家位置
    local last = moon.millsecond()
    moon.repeated(50,-1,function ( )
        local now = moon.millsecond()
        --参见ComponentsIndex
        start.dispatch(1,(now-last)/1000)
        last = now
    end)
end)

moon.destroy(function ( )
    start.destroy()
end)
