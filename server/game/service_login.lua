local moon = require("moon")
local seri = require("seri")
local json = require("json")

local gate_service

local uuid = 1 --player uid

local login_state ={}
local map_playerid_username ={}

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

--登陆流程step2 进行认证，并返回给gate_service
command.login = function(sessionid, msg)
	local data = json.decode(msg:substr(2,-1))
	local res = {ret="OK",sessionid=sessionid,playerid=0}
	if login_state[data.username]  then
		res.ret="ONLINE"
	else
		res.ret="OK"
		res.playerid = uuid
		login_state[data.username] = true
		map_playerid_username[res.playerid] = data.username
		uuid=uuid+1
	end
	moon.raw_send('lua', gate_service,seri.packs("login_res"),seri.pack(res))
end

command.client_close = function(playerid, _)
	local username = map_playerid_username[playerid]
	if username then
		login_state[username] = nil
		map_playerid_username[playerid] = nil
	end
end

moon.start(function()

	gate_service = moon.unique_service("gate")

    moon.dispatch('lua',function(msg,_)
		local sender = msg:sender()
        local header = msg:header()
        docmd(sender, header, msg)
    end)
end)
