local moon = require("moon")
local seri = require("seri")
local buffer = require("buffer")
local setup = require("common.setup")
local constant = require("common.constant")
local msgutil = require("common.msgutil")
local message = require("message")
local mdecode = msgutil.decode

local bsubstr = buffer.substr

local PCLIENT = constant.PTYPE.CLIENT

---@class agent_context
local context = {
    openid = 0,
    uid = 0,
    ismatching = false,
    room = false
}

context.send = function(msgid, mdata)
    moon.raw_send("toclient", context.gate, seri.packs(context.uid), msgutil.encode(msgid, mdata))
end

local function forward(msg)
    local buf = moon.decode(msg, "B")
    local msgid = string.unpack("<H", bsubstr(buf, 0, 2))
    if (msgid & 0xFF00) == 0x0200 then
        local header = seri.packs(context.uid)
        message.redirect(msg, header, context.center, PCLIENT)
        return true
    elseif (msgid & 0xFF00) == 0x0300 and context.room then
        local header = seri.packs(context.uid)
        message.redirect(msg, header, context.room, PCLIENT)
        return true
    end
    return false
end

context.forward = forward

local _, command = setup(context)

moon.dispatch(
    "client",
    function(msg)
        local buf = moon.decode(msg, "B")
        local cmd, data = mdecode(buf)
        local f = command[cmd]
        if f then
            moon.async(function()
                f(data)
            end)
        elseif forward(msg) then
            return
        else
            error(string.format("agent: PTYPE_CLIENT receive unknown cmd %s. uid %u", tostring(cmd), context.uid))
        end
    end
)

context.gate = moon.queryservice("gate")
context.center = moon.queryservice("center")

