local moon = require("moon")
---@type fs
local fs = require("fs")
local seri = require("seri")
local constant = require("common.constant")
local msgutil = require("common.msgutil")

local unpack = seri.unpack

local mdecode = msgutil.decode

local command = {}

local function docmd(sender, sessionid, cmd, ...)
    local f = command[cmd]
    if f then
        local args = {...}
        moon.async(function()
            moon.response("lua", sender, sessionid, f(table.unpack(args)))
        end)
    else
        assert("recv unknown cmd "..cmd)
    end
end

return function(context)

    context.docmd = docmd

    -- Load Handlers
    local dir = string.format("game/%s/handler/",moon.name())
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

    moon.dispatch("lua",function(msg,p)
        local sessionid = msg:sessionid()
        local sender = msg:sender()
        docmd(sender, sessionid, p.unpack(msg))
    end)

    moon.register_protocol({
        name = "client",
        PTYPE = constant.PTYPE.CLIENT,
        dispatch = function(msg)
            -- message id to name
            local cmd,data = mdecode(msg)
            local f = command[cmd]
            if f then
                -- mark 处理返回？？？
                f(data, msg)
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

    return docmd, command
end


