local moon = require("moon")
local buffer = require("buffer")
---@type fs
local fs = require("fs")
local seri = require("seri")
local constant = require("common.constant")
local msgutil = require("common.msgutil")

local unpack = seri.unpack
local unpack_one = seri.unpack_one
local pack = seri.pack
local packs = seri.packs

local buf_write_front = buffer.write_front

local mdecode = msgutil.decode

local raw_send = moon.raw_send

local command = {}

local function direct_docmd(sender, sessionid, cmd, ...)
    local args = {...}
    local f = command[cmd]
    if f then
        moon.async(function()
            moon.response("lua", sender, sessionid, f(table.unpack(args)))
        end)
    else
        assert("recv unknown cmd "..cmd)
    end
end

return function(context, sname)

    sname = sname or moon.name()

    -- Load Handlers
    local dir = string.format("game/%s/handler/", sname)

    local list = fs.listdir(dir,10)
    for _, filepath in ipairs(list) do
        if not fs.isdir(filepath) then
            local name = fs.filename(filepath)
            local f = assert(loadfile(dir..name))
            local res = f(context)
            if type(res) == "table" then
                for k,v in pairs(res) do
                    assert(type(v) == "function")
                    assert(not command[k])
                    command[k] = v
                end
            else
                assert(false)
            end
        end
    end

    moon.dispatch("lua",function(msg)
        local sender, sessionid, buf = moon.decode(msg, "SEB")
        local cmd, sz, len = unpack_one(buf)
        local fn = command[cmd]
        if fn then
            moon.async(function()
                if sessionid ~= 0 then
                    local unsafe_buf = pack(pcall(fn, unpack(sz, len)))
                    local ok = unpack_one(unsafe_buf, true)
                    if not ok then
                        buf_write_front(unsafe_buf, packs(false))
                    end
                    raw_send("lua", sender, "", unsafe_buf, sessionid)
                else
                    fn(unpack(sz, len))
                end
            end)
        else
            moon.error(moon.name(), "recv unknown cmd "..tostring(cmd))
        end
    end)

    moon.register_protocol({
        name = "client",
        PTYPE = constant.PTYPE.CLIENT,
        -- 定义默认的，agent 转发的客户端消息处理
        dispatch = function(msg)
            local header, buf = moon.decode(msg, "HB")
            -- agent 会把uid保存在header中
            local uid = seri.unpack(header)
            -- message id to string
            local cmd, data = mdecode(buf)
            -- find handler
            local f = command[cmd]
            if f then
                -- mark 处理返回？？？
                f(uid, data)
            else
                assert("PTYPE_CLIENT receive unknown cmd "..tostring(cmd))
            end
        end
    })

    moon.register_protocol({
        name = "toclient",
        PTYPE = constant.PTYPE.TO_CLIENT,
        dispatch = nil
    })

    return direct_docmd, command
end


