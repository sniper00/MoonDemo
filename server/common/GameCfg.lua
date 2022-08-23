local sharetable = require("moon.service.sharetable")

---@class confutil : static_conf
local M = {}

---@type static_conf
local static

function M.Load()
    static = sharetable.queryall()
    static.__index = static
    setmetatable(M, static)
end

function M.Reload(names)
    for _, name in ipairs(names) do
        static[name] = sharetable.query(name..".lua")
    end
end

return M
