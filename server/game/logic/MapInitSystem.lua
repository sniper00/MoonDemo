local require = require("import")

local Components = require('Components')
local class = class or require("base.class")
local M = class("FoodInitSystem")

function M:ctor(contexts,helper)
    self.context = contexts.input
    self.input_entity = self.context.input_entity
end

function M:initialize()
    -- 初始化food
    self.input_entity:replace(Components.InputCreateFood,500)
end

return M
