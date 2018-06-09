local aoi = require("aoi")

local M ={}

local space = aoi.create()

local cache = {}
local drop ={}

local scale = 1

function M.add( id )
    drop[id] = nil
end

function M.update_pos( id, mode, x, y )
    if mode == 'd' then
        for k,v in pairs(cache) do
            if k ~= id then
                v[id]=nil
                M.on_leave(k,id)
            end
        end
        cache[id] = nil
        drop[id] = true
        --print("drop end",id)
    end
    space:update(id,mode,x*scale,y*scale,0)
end

local function message( watcher,  marker )
    --print("aoi",watcher,"->",marker)
    if drop[watcher] or drop[marker] then
        return
    end
    if not cache[watcher] then
        cache[watcher] = {}
    end

    if not cache[watcher][marker] then
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