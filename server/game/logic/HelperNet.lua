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
    moon.raw_send('lua', gate_service,seri.packs("logout",uid))
end

local t = {id = 0,data=nil}

M.send_component = function(uid, entity, comp)
    if entity:has(comp) then
        t.id = entity:get(Components.BaseData).id
        t.data = entity:get(comp)
        moon.raw_send('lua', gate_service,seri.packs("S2C",uid),MSGID.encode(Components.GetID(comp),t))
    end
end

M.make_prefab =function(entity, comp)
    t.id = entity:get(Components.BaseData).id
    t.data = entity:get(comp)
    return moon.make_prefab(MSGID.encode(Components.GetID(comp),t))
end

M.send_prefab =function(uid, prefabid)
    moon.send_prefab(gate_service,prefabid,seri.packs("S2C",uid),0,moon.PTYPE_LUA)
end

return M
