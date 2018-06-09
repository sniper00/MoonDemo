local moon = require("moon")
local MSGID = require("MSGID")
local seri = require("seri")

local M = {}

local gate_service

M.set_gate_service = function ( sid )
    gate_service = sid
end

M.send =function(playeid, msgid,t)
    moon.raw_send('lua', gate_service,seri.packstring("S2C",playeid),MSGID.encode(msgid,t))
end

return M
