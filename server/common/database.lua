local json = require("json")
local redisd = require("redisd")

local jencode = json.encode

local jdecode = json.decode

local redis_call = redisd.call

local redis_hcall = redisd.hash_call

local redis_send = redisd.send

local redis_hsend = redisd.hash_send

local _M = {}

function _M.loadallopenid(addr_db)
    local res, err = redis_call(addr_db, "hgetall", "openidmap")
    if res == false then
        error("loadallopenid failed:"..tostring(err))
    end
    return res
end

function _M.loadserverdata(addr_db)
    local res, err = redis_call(addr_db, "get", "serverdata")
    if res == false then
        error("loadserverdata failed:"..tostring(err))
    end
    return res
end

function _M.saveserverdata(addr_db, data)
    local res, err = redis_call(addr_db, "set", "serverdata", data)
    if res == false then
        error("loadserverdata failed:"..tostring(err))
    end
    return res
end

function _M.queryuserid(addr_db, openid)
    local res, err = redis_call(addr_db, "hget", "openidmap", openid)
    if res == false then
        error("queryuserid failed:"..tostring(err))
    end

    if res then
        return math.tointeger(res)
    end

    return res
end

function _M.insertuserid(addr_db , openid, userid)
    redis_send(addr_db, "hset", "openidmap", openid, userid)
end

function _M.loaduser(addr_db, userid)
    local res, err = redis_hcall(userid, addr_db, "hget", "usermap", userid)
    if res == false then
        error("loaduser failed:"..tostring(err))
    end

    if res then
        res = jdecode(res)
    end

    return res
end

function _M.saveuser(addr_db, userid, data)
    data = jencode(data)
    redis_hsend(userid, addr_db,  "hset", "usermap", userid, data)
end

return _M