local util = require("util")
local entitas = require("entitas")
local Components = require("Components")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local class = util.class

local M = class("CreateMoverSystem", ReactiveSystem)

function M:ctor(contexts, helper)
    M.super.ctor(self, contexts.input)
    self.context = contexts.game
    self.input_entity = contexts.input.input_entity
    self.idx = contexts.idx
    self.aoi = helper.aoi
end

function M:get_trigger()
    return {
        {
            Matcher({Components.CommandRemove}),
            GroupEvent.ADDED | GroupEvent.UPDATE
        }
    }
end

function M:filter(entity)
    return entity:has(Components.CommandRemove)
end

function M:execute()
    local cmd = self.input_entity:get(Components.CommandRemove)

    local e = self.idx:get_entity(cmd.id)
    if e then
        local npos = e:get(Components.Position)
        self.aoi.update_pos(cmd.id, "d", npos.x, npos.y)
        self.aoi.update_message()
        self.context:destroy_entity(e)
    end

    print("remove mover", cmd.id)
end

return M
