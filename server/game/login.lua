local moon = require("moon")
local cluster = require("moon.cluster")
local login = require("service.loginserver")
local crypt = require("crypt")

local conf = ...

local server_list = {}
local user_online = {}

local function call_server(server, address ,...)
	if type(address) == "number" then
		return moon.co_call("lua", address, ...)
	else
		return cluster.send(server, address, ...)
	end
end

conf.auth_handler = function(token)
    local user, server, password = token:match("([^@]+)@([^:]+):(.+)")
	user = crypt.base64decode(user)
	server = crypt.base64decode(server)
	password = crypt.base64decode(password)
	--assert(password=="123456")
	--print(user, password, server)
    return server, user
end

conf.login_handler = function(server, openid, secret)
    print(string.format("LOGIN: %s@%s is login, secret is %s", openid, server, crypt.hexencode(secret)))
    local gameserver = assert(server_list[server], "Unknown server "..server)
	-- only one can login, because disallow multilogin
	local last = user_online[openid]
	if last then
		call_server(last.server, last.address, "kick", openid, last.uid)
	end

	if user_online[openid] then
		error(string.format("user %s is already online", openid))
	end

	local uid,err = call_server(server, gameserver, "login", openid, secret)
	assert(uid,err)
	user_online[openid] = { address = gameserver, uid = uid , server = server}
	return uid
end

local CMD = {}

function CMD.register_gate(server, address)
    print("login server register",server, address)
	server_list[server] = address
end

function CMD.logout(openid, uid)
	local u = user_online[openid]
	if u then
		print(string.format("LOGIN: client %s@%s logout. uid: %s", openid, u.server, tostring(uid)))
		user_online[openid] = nil
		return true
	end
	return false
end

function conf.command_handler(command, ...)
	local f = assert(CMD[command])
	return f(...)
end

login(conf)