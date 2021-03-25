-- require("LuaPanda").start("127.0.0.1", 8818)
local moon = require("moon")
local seri = require("seri")
local buffer = require("buffer")
local setup = require("common.setup")
local msgutil = require("common.msgutil")
local msgcode = require("common.msgcode")
local constant = require("common.constant")

local bsubstr = buffer.substr

local mdecode = msgutil.decode
local mencode = msgutil.encode

local fwd_addr = msgcode.forward

local bytes_to_name = msgutil.bytes_to_name

local redirect = moon.redirect

local PCLIENT = constant.PTYPE.CLIENT

---@class user_context
---@field public logics user_models
local context = {
    uid = 0,
    models = {}, --model 目录下文件
    ---other service address
    addr_gate = false,
    addr_db_user = false,
    addr_center = false,
    addr_room = false,
}

context.send = function(msgid, mdata)
    moon.raw_send("toclient", context.addr_gate, seri.packs(context.uid), mencode(msgid, mdata))
end

local _, command = setup(context, "user")

local function forward(msg, msgname)
    local address
    local v = fwd_addr[msgname]
    if v then
        address = context[v]
    end

    if not address then
        moon.error("recv unknown message", msgname)
        return
    end

    local header = seri.packs(context.uid)
    redirect(msg, header, address, PCLIENT)
end

moon.dispatch("client",function(msg)
    local buf = moon.decode(msg, "B")
    local msgname = bytes_to_name(bsubstr(buf, 0, 2))
    if not command[msgname] then
        forward(msg, msgname)
    else
        local cmd, data = mdecode(buf)
        local fn = command[cmd]
        moon.async(function()
            fn(data)
        end)
    end
end)

context.addr_gate = moon.queryservice("gate")
context.addr_db_user = moon.queryservice("db_user")
context.addr_center = moon.queryservice("center")

print(context.addr_gate,context.addr_db_user )

moon.shutdown(function()
    --- rewrite default behavior: quit immediately
end)
