local require = require("import")

local moon = require("moon")
local seri = require("seri")
local MSGID = require("game.MSGID")
local Components = require("Components")

local M = {}

local gate_service

M.set_gate_service = function ( sid )
    gate_service = sid
end

M.send =function(uid, msgid, mdata)
    moon.raw_send('lua', gate_service,seri.packs("S2C",uid),MSGID.encode(msgid,mdata))
end

M.close =function(uid)
    moon.raw_send('lua', gate_service,seri.packs("CLOSE_CLIENT",uid))
end

M.send_component = function(uid, entity, comp)
    if entity:has(comp) then
        local entity_id = entity:get(Components.BaseData).id
        local c = entity:get(comp)
        local t = {id = entity_id,data=c}
        moon.raw_send('lua', gate_service,seri.packs("S2C",uid),MSGID.encode(comp._id,t))
    end
end

M.prepare =function(entity, comp)
    local entity_id = entity:get(Components.BaseData).id
    local c = entity:get(comp)
    local t = {id = entity_id,data=c}
    local comp_id = comp._id
    return moon.prepare(MSGID.encode(comp_id,t))
end

M.send_prepare =function(uid, prepareid)
    moon.send_prepare(gate_service,prepareid,seri.packs("S2C",uid),0,moon.PTYPE_LUA)
end

return M
