local moon = require("moon")
local common = require("common")

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
	addr_gate = 0,
	addr_db_server = 0,
	addr_db_openid = 0,
    user_db = 0
}

local command = common.setup(context)

command.hotfix = function(names)
    for _,u in pairs(context.uid_map) do
        moon.send("lua", u.addr_user, "hotfix", names)
    end
end
