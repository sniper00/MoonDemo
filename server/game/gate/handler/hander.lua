local crypt = require("crypt")
local moon = require("moon")
local json = require("json")
local socket = require("moon.socket")
local cluster = require("moon.cluster")
local msgcode = require("common.msgcode")
local msgutil = require("common.msgutil")

local assert = assert
local b64decode = crypt.base64decode
local b64encode = crypt.base64encode

---@type gate_context
local context = ...

local openid_map = context.openid_map
local usertoken_map = context.usertoken_map
local uid_map = context.uid_map

local connection = context.connection

local function make_userid(username)
	-- base64(openid)@base64(server)#base64(uid)
	local openid, servername, uid = username:match "([^@]*)@([^#]*)#(.*)"
	return b64decode(openid), b64decode(uid), b64decode(servername)
end

local function make_usertoken(openid, uid, servername)
	return string.format("%s@%s#%s", b64encode(openid), b64encode(servername), b64encode(tostring(uid)))
end

local function call_login(...)
    local login = moon.queryservice("login")
    if 0 == login then
        return cluster.call("login", "login", ...)
    else
        return moon.co_call("lua", login,...)
    end
end

local internal_id = 0

local CMD = {}

--- called by loginserver
---@param openid string
function CMD.login(openid, secret)
    assert(not openid_map[openid], string.format("%s is already login", openid))

    internal_id = internal_id + 1
	local id = internal_id	-- don't use internal_id directly
    local usertoken = make_usertoken(openid, id, moon.get_env("SERVER_NAME"))

    local agent = moon.co_new_service("lua",{name="agent", file="game/agent.lua"})

	local u = {
		usertoken = usertoken,
		agent = agent,
		openid = openid,
        uid = id,
        secret = secret,
        version = 0,
    }
    assert(moon.co_call("lua", agent, "login", openid, id, secret))

    openid_map[openid] = u
    usertoken_map[usertoken] = u
    --print_r(u)
    return id
end


local function do_auth(fd, req)
    local usertoken, index, hmac = string.match(req.token, "([^:]*):([^:]*):([^:]*)")
    local u = usertoken_map[usertoken]
    if u == nil then
        return "404 User Not Found"
    end

    local idx = assert(tonumber(index))
    hmac = b64decode(hmac)

    if idx <= u.version then
        return "403 Index Expired"
    end

    local text = string.format("%s:%s", usertoken, index)
    local v = crypt.hmac_hash(u.secret, text)	-- equivalent to crypt.hmac64(crypt.hashkey(text), u.secret)
    if v ~= hmac then
        return "401 Unauthorized"
    end

    connection[fd] = u
    uid_map[u.uid] = fd
end

--- request by client
function CMD.auth(fd, req)
    req = json.decode(req:sub(3))-- skip 2 byte msgid, then decode
	local ok, result = pcall(do_auth, fd, req)
    if not ok then
        --print("gate auth", result)
        result = "400 Bad Request"
    end

    local close = result ~= nil

    if result == nil then
        result = "200 OK"
    end

    socket.write(fd, msgutil.encode(msgcode.S2CLogin,{res = result}))

    if close then
        socket.close(fd)
    end
end

function CMD.kick(openid, uid)
    --print("gate kick", openid, uid)
    local u = openid_map[openid]
	if u then
		local usertoken = make_usertoken(openid, uid, moon.get_env("SERVER_NAME"))
        assert(u.usertoken == usertoken)
		pcall(moon.co_call,"lua", u.agent, "logout")
    end
    return true
end

---used by agent
function CMD.logout(openid, uid)
    local u = openid_map[openid]
    if u then
        print(string.format("GATE: agent logout openid %s uid %s", tostring(openid), tostring(uid)))
		local usertoken = make_usertoken(openid, uid, moon.get_env("SERVER_NAME"))
		assert(u.usertoken == usertoken)
		openid_map[openid] = nil
        usertoken_map[u.usertoken] = nil
        return call_login("logout",openid, uid)
	end
end

return CMD