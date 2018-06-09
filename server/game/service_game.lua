local moon = require("moon")
local seri = require("seri")
local json = require("json")
local start = require("Start")
local HelperNet = require("HelperNet")

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

command.C2S = function(playerid, msg)
    local id = string.unpack("<H",msg:substr(0,2))
    start.dispatch(id,playerid,json.decode(msg:substr(2,-1)))
end

command.client_close = function(playerid)
    start.dispatch(2,playerid)
end

moon.start(function()
    HelperNet.set_gate_service(moon.unique_service("gate"))

    moon.dispatch('lua',function(msg,_)
		local sender = msg:sender()
        local header = msg:header()
        docmd(sender, header, msg)
    end)

    start.init()

    local last = moon.millsecond()
    moon.repeated(50,-1,function ( )
        local now = moon.millsecond()
        start.dispatch(1,(now-last)/1000)
        last = now
    end)
end)

moon.destroy(function ( )
    start.destroy()
end)
