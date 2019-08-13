local moon = require("moon")
local crypt = require("crypt")
local seri = require("seri")
local socket = require("moon.socket")

--[[

Protocol:

	line (\n) based text protocol

	1. Server->Client : base64(8bytes random challenge)
	2. Client->Server : base64(8bytes handshake client key)
	3. Server: Gen a 8bytes handshake server key
	4. Server->Client : base64(DH-Exchange(server key))
	5. Server/Client secret := DH-Secret(client key/server key)
	6. Client->Server : base64(HMAC(challenge, secret))
	7. Client->Server : DES(secret, base64(token))
	8. Server : call auth_handler(token) -> server, openid (A user defined method)
	9. Server : call login_handler(server, openid, secret) ->uid (A user defined method)
	10. Server->Client : 200 base64(uid)

Error Code:
	401 Unauthorized . unauthorized by auth_handler
	403 Forbidden . login_handler failed
	406 Not Acceptable . already in login (disallow multi login)

Success:
	200 base64(uid)
]]

local socket_error = {}
local function assert_socket(service, v, fd)
	if v then
		return v
	else
		print(string.format("%s failed: socket (fd = %d) closed", service, fd))
		error(socket_error)
	end
end

-- set socket buffer limit (8K)
-- If the attacker send large package, close the socket
local AUTH_LEN_LIMIT = 8192

local function readline(fd)
    return socket.readline(fd, "\n", AUTH_LEN_LIMIT)
end


local function write(service, fd, text)
	assert_socket(service, socket.write(fd, text), fd)
end

local function run_slave(auth_handler)
    local function auth(fd)
        local challenge = crypt.randomkey()

		write("auth1", fd, crypt.base64encode(challenge).."\n")

		local handshake = assert_socket("auth2", readline(fd), fd)
		local clientkey = crypt.base64decode(handshake)
		if #clientkey ~= 8 then
			error("Invalid client key")
		end
		local serverkey = crypt.randomkey()
		write("auth3", fd, crypt.base64encode(crypt.dhexchange(serverkey)).."\n")

        local secret = crypt.dhsecret(clientkey, serverkey)

        --print("sceret is ", crypt.hexencode(secret))

		local response = assert_socket("auth4", readline(fd), fd)
		local hmac = crypt.hmac64(challenge, secret)

		if hmac ~= crypt.base64decode(response) then
			error "challenge failed"
		end

		local etoken = assert_socket("auth5", readline(fd),fd)

		local token = crypt.desdecode(secret, crypt.base64decode(etoken))

		local ok, server, openid =  pcall(auth_handler,token)

		return ok, server, openid, secret
    end

    local function ret_pack(ok, err, ...)
		if ok then
			return seri.pack(err, ...)
		else
			if err == socket_error then
				return seri.pack(nil, "socket error")
			else
				return seri.pack(false, err)
			end
		end
	end

    local command = {}

    command.START =  function(sender,sessionid,fd)
        moon.async(function()
            local p = ret_pack(pcall(auth, fd))
            moon.raw_send("lua",sender,nil,p,sessionid)
        end)
    end

    command.END =  function(sender,sessionid,fd,data)
        socket.write(fd,data)
        moon.response("lua", sender, sessionid, "")
        print("login server client close ", fd, socket.close(fd))
    end

    local function docmd(sender,sessionid, CMD,...)
        local f = command[CMD]
        if f then
            f(sender,sessionid, ...)
        else
            error(string.format("Unknown command %s", tostring(CMD)))
        end
    end

    moon.dispatch('lua',function(msg,p)
        local sender = msg:sender()
        local sessionid = msg:sessionid()
        docmd(sender,sessionid, p.unpack(msg))
    end)
end

local user_login = {}

local function accept(conf, sid, fd)
    local ok, server, openid, secret = moon.co_call("lua", sid, "START", fd)
    if not ok then
        if ok ~= nil then
            moon.co_call("lua", sid, "END",fd, "401 Unauthorized\n")
        end
        error(server)
    end

    if not conf.multilogin then
        if user_login[openid] then
            moon.co_call("lua", sid, "END", fd, "406 Not Acceptable\n")
            error(string.format("User %s is already login", openid))
        end
        user_login[openid] = true
    end

    local ok, err = pcall(conf.login_handler, server, openid, secret)
	-- unlock login
	user_login[openid] = nil

	if ok then
        err = err or ""
        moon.co_call("lua", sid, "END", fd, "200 "..crypt.base64encode(err).."\n")
    else
        moon.co_call("lua", sid, "END", fd, "403 Forbidden\n")
		error(err)
	end
end

local function run_master(conf)

    moon.dispatch("lua", function(msg, p)
        moon.response("lua",msg:sender(),msg:sessionid(), conf.command_handler(p.unpack(msg:bytes())))
    end)

    local listenfd  = socket.listen(conf.host,conf.port,moon.PTYPE_TEXT)

    local slave = {}

    moon.async(function()
        for n=1,conf.count do
            local sid = moon.co_new_service("lua",{name=conf.name.."-slave"..n,file = conf.file})
            table.insert(slave,sid)
        end

        local balance = 1
        while true do
            if balance>#slave then
                balance = 1
            end
            local fd = socket.accept(listenfd,slave[balance])
            moon.async(function()
                local sid = slave[balance]
                local ok, err = pcall(accept, conf, sid, fd)
                if not ok then
                    if err ~= socket_error then
                        print(string.format("invalid client (fd = %d) error = %s", fd, err))
                    end
                end
            end)
            balance = balance + 1
        end
    end)

    moon.destroy(function()
        socket.close(listenfd)
    end)
end

local function run(conf)
    if conf.master then
        assert(conf.login_handler)
        assert(conf.command_handler)
        run_master(conf)
    else
        local auth_handler = assert(conf.auth_handler)
        run_slave(auth_handler)
    end
end

return run

