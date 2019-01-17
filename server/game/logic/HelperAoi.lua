local require = require("import")

local aoi = require("aoi")

local M = {}

local space

local cache = {}

function M.create(...)
    space = aoi.create(...)
end

function M.insert(id, x, y, mover)
    space:insert(id, x, y)
    if mover then
        cache[id] = {ver = 1, view = {}}
    end
end

function M.update(...)
    space:update(...)
end

local removed = {}

function M.update_message()
    for id, value in pairs(cache) do
        value.ver = space:query(id, 20, 10, value.ver, value.view)
        local index = 0
        for oid, v in pairs(value.view) do
            if v == value.ver + 1 then
                M.on_enter(id, oid)
            elseif v ~= value.ver then
                index = index + 1
                removed[index] = oid
                M.on_leave(id, oid)
            end
        end
        for i=1, index  do
            value.view[removed[i]] = nil
        end
    end
end

function M.get_aoi(id)
    if not cache[id] then
        print("!!!", id)
        return
    end
    return cache[id].view
end

function M.erase(id, mover)
    if mover then
        print("erase", id)
        cache[id] = nil
    end
    return space:erase(id)
end

function M.cache_size()
    local maxcount = 0
    for _, value in pairs(cache) do
        local n = 0
        for _, _ in pairs(value.view) do
            n = n + 1
        end
        if n > maxcount then
            maxcount = n
        end
    end
    return maxcount
end

return M
