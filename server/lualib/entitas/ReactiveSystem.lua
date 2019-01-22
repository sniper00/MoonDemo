local array = require("base.array")
local Collector = require("entitas.Collector")

local M = class("ReactiveSystem")

local function get_collector(self, context)
    local trigger = self:get_trigger()
    local groups = {}

    for _,one in pairs(trigger) do
        local matcher = one[1]
        local group_event = one[2]
        local group = context:get_group(matcher)
        groups[group] = group_event
    end

    return Collector.new(groups)
end

function M:ctor(context)
    self._collector = get_collector(self, context)
    self._entities = array.new(true)
end

function M:get_trigger()
    error(self.__cname.." 'get_trigger' not implemented")
end

function M:filter()
    error(self.__cname.." 'filter' not implemented")
end

function M:execute()
    error(self.__cname.." 'execute' not implemented")
end

function M:activate()
    self._collector:activate()
end

function M:deactivate()
    self._collector:deactivate()
end

function M:clear()
    self._collector:clear_entities()
end

function M:_execute()
    local entities = self._entities
    if self._collector.entities:size()>0 then
        self._collector.entities:foreach(function(entity)
            if self:filter(entity) then
                entities:push(entity)
            end
        end)

        self._collector:clear_entities()

        if entities:size() > 0 then
            self:execute(entities)
            entities:clear()
        end
    end
end

return M
