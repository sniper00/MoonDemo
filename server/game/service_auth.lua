local moon = require("moon")
local common = require("common")

---@class auth_context:base_context
---@field uid_map table<integer,AuthUser> @内存加载的玩家服务信息
---@field scripts auth_scripts
local context = {
    uid_map = {},
    openid_map = {},--- map<openid, uid>
    auth_queue = {},
    service_counter = 0,
    scripts = {},
}

local command = common.setup(context)

command.hotfix = function(names)
    for _,u in pairs(context.uid_map) do
        moon.send("lua", u.addr_user, "hotfix", names)
    end

    for uid, q in pairs(context.auth_queue) do
        if q("counter") >0 then
            moon.async(function()
                context.scripts.Auth.SendUser(uid, "hotfix", names)
            end)
        end
    end
end

