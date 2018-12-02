local Entity        = require("entitas.Entity")
local Group         = require("entitas.Group")
local Matcher       = require("entitas.Matcher")

local table_insert  = table.insert
local table_remove  = table.remove

--[[
    The Context is the factory where you create and destroy entities.
    Use it to filter entities of interest.
]]
local M = {}

M.__index = M

function M.new()
    local tb = {}
    -- Entities retained by this context.
    tb.entities = {}
    -- An object pool to recycle entities.
    tb._entities_pool = {}
    -- Entities counter
    tb._uuid = 1
    tb._size = 0
    -- Dictionary of matchers mapping groups.
    tb._groups = {}
    tb._entity_indices = {}
    tb.comp_added = function(...) return tb._comp_added(tb, ...) end
    tb.comp_removed = function(...) return tb._comp_removed(tb, ...) end
    tb.comp_replaced = function(...) return tb._comp_replaced(tb, ...) end
    return setmetatable(tb, M)
end

-- Checks if the context contains this entity.
function M:has_entity(entity)
    return self.entities[entity._uid]
end

--[[
Creates an entity. Pop one entity from the pool if it is not
empty, otherwise creates a new one. Increments the entity index.
Then adds the entity to the list.
:rtype: Entity
]]
function M:create_entity()
    local entity = table_remove(self._entities_pool)
    if not entity then
        entity = Entity.new()
        entity.on_component_added:add(self.comp_added)
        entity.on_component_removed:add(self.comp_removed)
        entity.on_component_replaced:add(self.comp_replaced)
    end

    entity:activate(self._uuid)
    self._uuid = self._uuid + 1
    self.entities[entity._uid] = entity
    self._size = self._size + 1
    return entity
end

--[[
Removes an entity from the list and add it to the pool. If
the context does not contain this entity, a
:class:`MissingEntity` exception is raised.
:param entity: Entity
]]
function M:destroy_entity(entity)
    if not self:has_entity(entity) then
        error("The context does not contain this entity.")
    end

    entity:destroy()

    self.entities[entity._uid] = nil
    table_insert(self._entities_pool, entity)
    self._size = self._size - 1
end

function M:entity_size()
    return self._size
end

--[[
User can ask for a group of entities from the context. The
group is identified through a :class:`Matcher`.
:param entity: Matcher
]]
function M:get_group(matcher)
    local group = self._groups[matcher]
    if group then
        return group
    end

    group = Group.new(matcher)

    for _,e in pairs(self.entities) do
        group:handle_entity_silently(e)
    end

    self._groups[matcher] = group

    return group
end

function M:set_unique_component(comp_type, ...)
    local entity = self:create_entity()
    entity:add(comp_type, ...)
end

function M:get_unique_component(comp_type)
    local group = self:get_group(Matcher({comp_type}))
    local entity = group:single_entity()
    return entity:get(comp_type)
end

function M:add_entity_index(entity_index)
    self._entity_indices[entity_index.comp_type] = entity_index
end

function M:get_entity_index(comp_type)
    return self._entity_indices[comp_type]
end

function M:_comp_added(entity, comp_value)
    for _, group in pairs(self._groups) do
        if group._matcher:match_one(comp_value) then
            group:handle_entity(entity, comp_value)
        end
    end
end

function M:_comp_removed(entity, comp_value)
    for _, group in pairs(self._groups) do
        if group._matcher:match_one(comp_value) then
            group:handle_entity(entity, comp_value,true)
        end
    end
end

function M:_comp_replaced(entity, comp_value)
    for _, group in pairs(self._groups) do
        if group._matcher:match_one(comp_value) then
            group:update_entity(entity, comp_value)
        end
    end
end

return M
