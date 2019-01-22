local set           = require("base.set")
local class         = class or ("base.class")
local set_insert    = set.insert
local set_remove    = set.remove

local AbstractEntityIndex = require("entitas.AbstractEntityIndex")

local M = class("EntityIndex", AbstractEntityIndex)

function M:ctor(comp_type, group, ...)
    M.super.ctor(self, comp_type, group, ...)
end

function M:get_entities(key)
    --print("key", key)
    if not self._indexes[key] then
        self._indexes[key] = set.new(true)
    end
    return self._indexes[key]
end

function M:_add_entity(key, entity)
    --print("ecs_idx:add", key, "entity", entity)
    local t = self:get_entities(key)
    set_insert(t, entity)
end

function M:_remove_entity(key, entity)
    --print("ecs_idx:remove", key, "entity", entity)
    local t = self:get_entities(key)
    set_remove(t, entity)
end

return M
