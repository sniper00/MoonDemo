local moon = require("moon")
local buffer = require("buffer")
local reload = require("hardreload")
---@type fs
local fs = require("fs")
local seri = require("seri")
local constant = require("common.constant")
local msgutil = require("common.msgutil")

local strfmt = string.format
local traceback = debug.traceback

local unpack = seri.unpack
local unpack_one = seri.unpack_one
local pack = seri.pack
local packs = seri.packs

local buf_write_front = buffer.write_front

local mdecode = msgutil.decode

local raw_send = moon.raw_send
local get_env = moon.get_env
local async = moon.async

local command = {}

local function direct_docmd(cmd, ...)
    local args = {...}
    local f = command[cmd]
    if f then
        moon.async(function()
            f(table.unpack(args))
        end)
    else
        assert("recv unknown cmd "..cmd)
    end
end

local function load_models(context, sname)
    local dir = strfmt("game/%s/model/", sname)

    local models = moon.get_env_unpack(dir)
    if not models then
        models = {}
        local list = fs.listdir(dir,10)
        for _, file in ipairs(list) do
            if not fs.isdir(file) then
                local name = fs.stem(file)
                models[name] = dir..name..".lua"
            end
        end
        moon.set_env_pack(dir, models)
    end

    for name, mod in pairs(models) do
        local fn
        local content = get_env(mod)
        if #content > 0 then
            fn = load(content, "@"..mod)
        else
            fn = assert(loadfile(mod))
        end
        local res = fn(context)
        assert(type(res) == "table")
        context.models[name] = res
        reload.register(mod, fn, res)
    end
end

local function load_handler_one(context, handler, isfix)
    local fn
    local content = get_env(handler)
    if #content > 0 then
        fn = load(content, "@"..handler)
    else
        fn = assert(loadfile(handler))
    end
    local res = fn(context)
    assert(type(res) == "table")
    for k,v in pairs(res) do
        assert(type(v) == "function")
        assert(not command[k] or isfix or k:sub(1,1)=="_", "handler cmd name duplicate: "..k)
        command[k] = v
    end
end

local function load_handler(context, sname, isfix)
    local dir = strfmt("game/%s/handler/", sname)

    local handlers = moon.get_env_unpack(dir)

    if not handlers then
        handlers = {}
        local list = fs.listdir(dir,10)
        for _, file in ipairs(list) do
            if not fs.isdir(file) then
                local name = fs.stem(file)
                handlers[name] = dir..name..".lua"
            end
        end
        moon.set_env_pack(dir, handlers)
    end

    for _, handler in pairs(handlers) do
        load_handler_one(context, handler, isfix)
    end
end

local function _internal(context)
    command._hotfix = function (fixlist)
        for _, mod in ipairs(fixlist) do
            if context.logics[fs.stem(mod)] then
                local ok, res = reload.reload(mod)
                if ok then
                    print(moon.name, "hotfix" , mod)
                else
                    moon.error(moon.name, "hotfix failed" , res, mod)
                end
            else
                load_handler_one(context, mod, true)
                print(moon.name, moon.addr(), "hotfixhandler" , mod)
            end
        end
        collectgarbage("collect")
    end
end

return function(context, sname)

    sname = sname or moon.name

    if not context.logics then
        context.logics = {}
    end

    load_models(context, sname)

    _internal(context)

    load_handler(context, sname)

    moon.dispatch("lua",function(msg)
        local sender, sessionid, buf = moon.decode(msg, "SEB")
        local cmd, sz, len = unpack_one(buf)
        local fn = command[cmd]
        if fn then
            async(function()
                if sessionid ~= 0 then
                    local unsafe_buf = pack(xpcall(fn, traceback, unpack(sz, len)))
                    local ok = unpack_one(unsafe_buf, true)
                    if not ok then
                        buf_write_front(unsafe_buf, packs(false))
                    end
                    raw_send("lua", sender, "", unsafe_buf, sessionid)
                else
                    fn(unpack(sz, len))
                end
                --collectgarbage("step")
            end)
        else
            moon.error(moon.name, "recv unknown cmd "..tostring(cmd))
        end
    end)

    moon.register_protocol({
        name = "client",
        PTYPE = constant.PTYPE.CLIENT,
        -- 定义默认的客户端消息处理
        dispatch = function(msg)
            local header, buf = moon.decode(msg, "HB")
            --agent把uid保存在header中
            local uid = unpack(header)
            -- message id to string
            local ok, cmd, data = pcall(mdecode, buf)
            if not ok then
                moon.error("protobuffer decode client message failed", cmd)
                moon.send("lua", context.gate, "Kick", uid)
                return
            end
            -- find handler
            local fn = command[cmd]
            if fn then
                moon.async(function()
                    fn(uid, data)
                end)
            else
                moon.error(moon.name, "receive unknown PTYPE_CLIENT cmd "..tostring(cmd) .. " " .. tostring(uid))
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


