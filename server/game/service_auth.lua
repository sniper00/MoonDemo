local moon = require("moon")
local setup = require("common.setup")

---@class AuthUser
---@field public addr_user integer @玩家服务address
---@field public openid string @
---@field public uid integer @玩家uid
---@field public logouttime integer @玩家登出时间
---@field public online boolean @是否在线

---@class auth_context:base_context
---@field public uid_map table<integer,AuthUser> @内存加载的玩家服务信息
---@field public scripts auth_scripts
local context = {
    uid_map = {},
    openid_map = {},--- map<openid, uid>
    service_counter = 0,
    scripts = {},
    ---other service address
	addr_gate = false,
	addr_db_server = false,
	addr_db_openid = false,
    user_db = false
}

local _, command = setup(context)

command.userhotfix = function(names)
    for _,u in pairs(context.uid_map) do
        moon.send("lua", u.addr_user, "hotfix", names)
    end
end
