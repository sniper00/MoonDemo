local moon = require("moon")
local seri = require("seri")
local setup = require("common.setup")
local msgutil = require("common.msgutil")

local conf = ...

local mdecode = msgutil.decode

---@class center_context
local context ={
    conf = conf,
    match_map={},
    match_queue={}
}

context.send = function(uid, msgid, mdata)
    moon.raw_send('toclient', context.gate, seri.packs(uid), msgutil.encode(msgid,mdata))
end

local _,command = setup(context)

moon.dispatch("client",function(msg)
    local uid, address = seri.unpack(msg:header())
    local cmd,data = mdecode(msg)
    local f = command[cmd]
    if f then
        f(uid, address, data, msg)
    else
        error(string.format("room: PTYPE_CLIENT receive unknown cmd %s. uid %u", tostring(cmd), uid))
    end
end)

moon.start(function()
    context.gate = moon.queryservice("gate")

end)
