local require = require("import")
local Components = require("Components")

local M = class("NetworkInputSystem")

function M:ctor(contexts)
    self.input_entity = contexts.input.input_entity
end

function M:dispatch(id,...)
    local comp = Components.GetComponent(id)
    assert(comp,"unknown comp "..string.format( "0x%04x",id))
    self.input_entity:replace(comp,...)
    --print("net_input",comp)
end

return M
