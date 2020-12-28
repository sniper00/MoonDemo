local aoi = require("aoi")

local AOI_WATCHER = 1
local AOI_MARHER = 2
local EVENT_ENTER = 1
local EVENT_LEAVE = 2

---@type room_context
local context = ...

---@class AoiModel
local AoiModel = {}

local space

local event_cache = {}
local function update_aoi_event(fn)
    local count = space:update_event(event_cache)
	for i=1,count,3 do
        local watcher = event_cache[i]
        local marker = event_cache[i+1]
		local eventid = event_cache[i+2]
        if eventid == EVENT_ENTER then
            context.docmd("AoiEnter", watcher, marker)
        elseif eventid == EVENT_LEAVE then
            context.docmd("AoiLeave", watcher, marker)
        else
            fn(watcher)
		end
	end
end

function AoiModel.Init(orginx, orginy, size)
    space = aoi.create(orginx, orginy, size, 16)
    space:enable_leave_event(true)
end

function AoiModel.Insert(id, x, y, view_size, mover)
    if mover then
        space:insert(id, x, y, view_size, view_size, 1, AOI_WATCHER|AOI_MARHER)
    else
        space:insert(id, x, y, 0, 0, 1, AOI_MARHER)
    end
    update_aoi_event()
end

function AoiModel.Update(id, x, y, view_size)
    space:update(id, x, y, view_size, view_size, 1)
    update_aoi_event()
end

function AoiModel.FireEvent(id, eventid, fn)
    space:fire_event(id, eventid)
    update_aoi_event(fn)
end

function AoiModel.Erase(id)
    local res = space:erase(id)
    update_aoi_event()
    return res
end

function AoiModel.Query(x, y, view_w, view_h)
    x = math.floor(x)
    y = math.floor(y)
    view_w = 2*math.ceil(view_w)
    view_h = 2*math.ceil(view_h)
    local out = {}
    space:query(x, y, view_w, view_h, out)
    return out
end

return AoiModel
