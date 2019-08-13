local moon = require("moon")
local seri = require("seri")
local setup = require("common.setup")
local constant = require("common.constant")
local msgutil = require("common.msgutil")
local mdecode = msgutil.decode

local PCLIENT = constant.PTYPE.CLIENT

local context ={
    openid = 0,
	uid = 0
}

local function forward(msg)
    local msgid = string.unpack("<H",msg:substr(0,2))
    if(msgid&0xFF00) == 0x0200 then
        local header = seri.packs(context.uid)
        msg:redirect(header,context.center,PCLIENT)
        return true
    elseif (msgid&0xFF00) == 0x0300 then
        local header = seri.packs(context.uid)
        msg:redirect(header,context.room,PCLIENT)
        return true
    end
    return false
end

local _, command = setup(context)

moon.dispatch("client",function(msg)
    if forward(msg) then
        return
    end

    local cmd,data = mdecode(msg)
    local f = command[cmd]
    if f then
        f(data, msg)
    else
        error(string.format("agent: PTYPE_CLIENT receive unknown cmd %s. uid %u", tostring(cmd), context.uid))
    end
end)

moon.start(function()
    context.gate = moon.queryservice("gate")
    context.center = moon.queryservice("center")
    context.room = moon.queryservice("room")
end)
