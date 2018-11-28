local aoi = require("aoi")

local M ={}

local space = aoi.create()

local cache = {}

local scale = 1

function M.update_pos( id, mode, x, y )
    if mode == 'd' then
        for k,v in pairs(cache) do
            if k ~= id then
                v[id]=nil
                M.on_leave(k,id)
            end
        end
        cache[id] = nil
    end
    space:update(id,mode,x*scale,y*scale,0)
end

local function message( watcher,  marker )
    if not cache[watcher] then
        cache[watcher] = {}
    end

    if not cache[watcher][marker] then
        --print("aoi",watcher,"->",marker)
        cache[watcher][marker] = true
        M.on_enter(watcher,marker)
    end
end

function M.update_message()
    space:message(message)
end

function M.get_aoi( id )
    return cache[id]
end

return M