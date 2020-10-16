local moon = require("moon")
local seri = require("seri")
local setup = require("common.setup")
local msgutil = require("common.msgutil")

local conf = ...

---@class center_context
local context ={
    conf = conf,
    match_map={},
    match_queue={},
    docmd = false
}

context.send = function(uid, msgid, mdata)
    moon.raw_send('toclient', context.gate, seri.packs(uid), msgutil.encode(msgid,mdata))
end

context.docmd = setup(context)
