require("common.LuaPanda").start("127.0.0.1", 8818)
local moon = require("moon")
local setup = require("common.setup")

local conf = ...

---@class user_scripts
---@field public Aoi Aoi
---@field public Room Room

---@class room_context:base_context
---@field public scripts user_scripts
local context ={
    conf = conf,
    models = {},
    docmd = false,
    uid_address = {},
    addr_gate = false,
    addr_auth = false
}

local docmd = setup(context,"room")
context.docmd = docmd

context.addr_gate = moon.queryservice("gate")
context.addr_auth = moon.queryservice("auth")
context.addr_center = moon.queryservice("center")

docmd("Init")

moon.async(function()
    while true do
        moon.sleep(100)
        docmd("Room.Update")
    end
end)

moon.timeout(conf.round_time*1000, function()
    docmd("Room.GameOver")
end)

moon.shutdown(function()
    --- rewrite default behavior: quit immediately
end)
