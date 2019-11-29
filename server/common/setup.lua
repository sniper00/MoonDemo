local moon = require("moon")
---@type fs
local fs = require("fs")
local seri = require("seri")
local constant = require("common.constant")
local msgutil = require("common.msgutil")

local unpack = seri.unpack

local unpack_one = seri.unpack_one

local mdecode = msgutil.decode

local command = {}

local function docmd(sender, sessionid, msg)
    local buffer = msg:buffer()
    local cmd = unpack_one(buffer)
    local f = command[cmd]
    if f then
        moon.async(function()
            moon.response("lua", sender, sessionid, f(unpack(buffer)))
        end)
    else
        assert("recv unknown cmd "..cmd)
    end
end

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
    fs.traverse_folder(dir, 100, function(filepath,isdir)
        if not isdir then
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
    end)

    moon.dispatch("lua",function(msg)
        local sessionid = msg:sessionid()
        local sender = msg:sender()
        docmd(sender, sessionid, msg)
    end)

    moon.register_protocol({
        name = "client",
        PTYPE = constant.PTYPE.CLIENT,
        -- 定义默认的，agent 转发的客户端消息处理
        dispatch = function(msg)
            -- agent 会把uid保存在header中
            local uid = seri.unpack(msg:header())
            -- message id to string
            local cmd,data = mdecode(msg)
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


