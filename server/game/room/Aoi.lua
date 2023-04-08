local aoi = require("aoi")
local uuid = require("uuid")
local common = require("common")
local CmdCode = common.CmdCode

local AOI_WATCHER = 1
local AOI_MARHER = 2
local EVENT_ENTER = 1
local EVENT_LEAVE = 2

---@type room_context
local context = ...

local scripts = context.scripts

---@class Aoi
local Aoi = {}

local space

local event_cache = {}
local function update_aoi_event(fn)
    local count = space:update_event(event_cache)
    local watchers
	for i=1,count,3 do
        local watcher = event_cache[i]
        local marker = event_cache[i+1]
		local eventid = event_cache[i+2]
        if eventid == EVENT_ENTER then
            Aoi.enter(watcher, marker)
        elseif eventid == EVENT_LEAVE then
            Aoi.leave(watcher, marker)
        else
            if not watchers then
                watchers = {}
            end
            watchers[#watchers+1] = watcher
		end
	end

    if watchers and next(watchers) then
        fn(watchers)
    end
end

function Aoi.init_map(orginx, orginy, size)
    space = aoi.new(orginx, orginy, size, 16)
    space:enable_leave_event(true)
end

function Aoi.insert(id, x, y, view_size, mover)
    if mover then
        space:insert(id, x, y, view_size, view_size, 1, AOI_WATCHER|AOI_MARHER)
    else
        space:insert(id, x, y, 0, 0, 1, AOI_MARHER)
    end
    update_aoi_event()
end

function Aoi.update(id, x, y, view_size)
    space:update(id, x, y, view_size, view_size, 1)
    update_aoi_event()
end

function Aoi.fireEvent(id, eventid, fn)
    space:fire_event(id, eventid)
    update_aoi_event(fn)
end

function Aoi.erase(id)
    local res = space:erase(id)
    update_aoi_event()
    return res
end

function Aoi.query(x, y, view_w, view_h)
    x = math.floor(x)
    y = math.floor(y)
    view_w = 2*math.ceil(view_w)
    view_h = 2*math.ceil(view_h)
    local out = {}
    space:query(x, y, view_w, view_h, out)
    return out
end

function Aoi.enter(watcher, marker)
    if uuid.isuid(marker) then
        context.S2C(watcher, CmdCode.S2CEnterView, scripts.Room.FindPlayer(marker))
    else
        context.S2C(watcher, CmdCode.S2CEnterView, scripts.Room.FindFood(marker))
    end
end

function Aoi.leave(watcher, marker)
    context.S2C(watcher, CmdCode.S2CLeaveView, {id = marker})
end

return Aoi
