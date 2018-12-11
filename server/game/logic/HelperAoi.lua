local aoi = require("aoi")

local M ={}

local space = aoi.create()

local cache = {}

local scale = 1

function M.update_pos( id, mode, x, y )
    if mode == 'd' then
        for watcher,views in pairs(cache) do
            if watcher ~= id then
                if views[id] then
                    views[id] = nil
                    M.on_leave(watcher,id)
                end
            end
        end
        cache[id] = nil
    end
    space:update(id,mode,x*scale,y*scale,0)
end

local function message( watcher,  marker )
    if M.set(watcher,marker,true) then
        --print("aoi",watcher,"->",marker)
        M.on_enter(watcher,marker)
    end
end

function M.update_message()
    space:message(message)
end

function M.get_aoi( id )
    local t = cache[id]
    if t then
        local tmp = {}
        for v,_ in pairs(t) do
            table.insert( tmp, v )
        end
        return tmp
    end
    return nil
end

function M.set( watcher, marker, value)
    local v = cache[watcher]
    if not v then
        v = {}
        cache[watcher] = v
    end
    local old = v[marker]
    if old ~= value then
        v[marker] = value
        return true
    end
    return false
end

function M.leave_view( watcher, marker  )
    if M.set( watcher, marker) then
        M.on_leave(watcher,marker)
    end
end

function M.cache_size()
    local maxcount = 0
    for _,views in pairs(cache) do
        local n = 0
        for _,_ in pairs(views) do
            n = n + 1
        end
        if n > maxcount then
            maxcount = n
        end
    end
    return maxcount
end

return M