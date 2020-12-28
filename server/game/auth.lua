local moon = require("moon")
local seri = require("seri")
local msgutil = require("common.msgutil")
local setup = require("common.setup")

local conf = ...

---@class AuthUser
---@field public addr_user integer @玩家服务address
---@field public openid string @
---@field public uid integer @玩家uid
---@field public logouttime integer @玩家登出时间
---@field public online boolean @是否在线

---@class auth_context
---@field uid_map AuthUser[] @内存中玩家数据
local context = {
    uid_map = {}, --- map<uid, user>
    openid_map = {},--- map<openid, uid>
	uid_map_count = 0,
    ---other service address
	addr_gate = false,
	addr_db_server = false,
	addr_db_openid = false,
}

context.send = function(uid, msgid, mdata)
    moon.raw_send('toclient', context.addr_gate, seri.packs(uid), msgutil.encode(msgid, mdata))
end

setup(context)


