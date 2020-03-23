local aoi = require("aoi")

local M = {}

local space

local cache = {}

local AOI_WATCHER = 1

local AOI_MARHER = 2

local EVENT_ENTER = 1

local EVENT_LEAVE = 2

M.EVENT_DEAD = 10

M.EVENT_EAT = 11

M.EVENT_UPDATE_DIR = 12

M.EVENT_UPDATE_RAIDUS = 13

M.EVENT_UPDATE_SPEED = 14

local event_cache = {}
local function update_aoi_event(fn)
    local count = space:update_event(event_cache)
	for i=1,count,3 do
        local watcher = event_cache[i]
        local marker = event_cache[i+1]
		local eventid = event_cache[i+2]
		if eventid == EVENT_ENTER then
            cache[watcher][marker] = true
            M.on_enter(watcher, marker)
        elseif eventid == EVENT_LEAVE then
            cache[watcher][marker] = nil
            M.on_leave(watcher, marker)
        else
            fn(watcher)
		end
	end
end

function M.create(...)
    space = aoi.create(...)
    space:enable_leave_event(true)
end

function M.insert(id, x, y, mover)
    if mover then
        space:insert(id, x, y, 18, 11, 1, AOI_WATCHER|AOI_MARHER)
        cache[id] = {}
    else
        space:insert(id, x, y, 0, 0, 1, AOI_MARHER)
    end

    update_aoi_event()
end

function M.update(id, x, y)
    space:update(id, x, y, 18, 11, 1)
    update_aoi_event()
end

function M.fire_event(id, eventid, fn)
    space:fire_event(id, eventid)
    update_aoi_event(fn)
end

function M.get_aoi(id)
    if not cache[id] then
        print("aoi !!!", id)
        return
    end
    return cache[id]
end

function M.erase(id, mover)
    if mover then
        print("aoi erase", id)
        cache[id] = nil
    end
    local res = space:erase(id)
    update_aoi_event()
    return res
end

function M.max_view_count()
    local maxcount = 0
    for _, value in pairs(cache) do
        local n = 0
        for _, _ in pairs(value) do
            n = n + 1
        end
        if n > maxcount then
            maxcount = n
        end
    end
    return maxcount
end

function M.mover_count()
    local count = 0
    for _, _ in pairs(cache) do
        count = count + 1
    end
    return count
end

return M
