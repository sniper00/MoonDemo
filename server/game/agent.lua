local moon = require("moon")
local seri = require("seri")
local setup = require("common.setup")
local constant = require("common.constant")
local msgutil = require("common.msgutil")
local mdecode = msgutil.decode

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
    local msgid = string.unpack("<H", msg:substr(0, 2))
    if (msgid & 0xFF00) == 0x0200 then
        local header = seri.packs(context.uid)
        moon.redirect(msg, header, context.center, PCLIENT)
        return true
    elseif (msgid & 0xFF00) == 0x0300 and context.room then
        local header = seri.packs(context.uid)
        moon.redirect(msg, header, context.room, PCLIENT)
        return true
    end
    return false
end

context.forward = forward

local _, command = setup(context)

moon.dispatch(
    "client",
    function(msg)
        local cmd, data = mdecode(msg)
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

moon.start(function()
    context.gate = moon.queryservice("gate")
    context.center = moon.queryservice("center")
end)
