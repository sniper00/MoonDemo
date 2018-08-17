local moon = require("moon")
local MSGID = require("MSGID")
local seri = require("seri")
local Components = require("Components")

local M = {}

local gate_service

M.set_gate_service = function ( sid )
    gate_service = sid
end

M.send =function(uid, msgid, mdata)
    moon.raw_send('lua', gate_service,seri.packstring("S2C",uid),MSGID.encode(msgid,mdata))
end

M.send_component = function(uid, entity, comp)
    if entity:has(comp) then
        local entity_id = entity:get(Components.BaseData).id
        local c = entity:get(comp)
        local t = {id = entity_id,data=c}
        moon.raw_send('lua', gate_service,seri.packstring("S2C",uid),MSGID.encode(comp._id,t))
    end
end

return M
