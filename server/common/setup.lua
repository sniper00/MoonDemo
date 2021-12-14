local moon = require("moon")
local reload = require("hardreload")
---@type fs
local fs = require("fs")
local seri = require("seri")
local datetime = require("moon.datetime")
local constant = require("common.constant")
local protocol = require("common.protocol")
local cmdcode = require("common.cmdcode")

local strfmt = string.format
local strbyte = string.byte
local traceback = debug.traceback

local unpack = moon.unpack
local pack = moon.pack
local raw_send = moon.raw_send

---@class base_context
---@field public send fun(uid:integer, msgid:integer, mdata:table) @ 给玩家发送消息
---@field public start_hour_timer fun() @ 开启整点定时器
---@field public batch_invoke fun(fnname:string) @批量调用所有脚本的函数
---@field public send_user fun(uid:integer, cmd:string, ...) @给玩家服务发送消息
---@field public call_user fun(uid:integer, cmd:string, ...) @调用玩家服务

local command = {}

reload.addsearcher(function(file)
    local content = moon.get_env(file)
    return load(content,"@"..file), file
end)

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

local function load_scripts(context, sname)
    local dir = strfmt("game/%s/", sname)
    local scripts = moon.get_env_unpack(dir)
    if not scripts then
        scripts = {}
        local list = fs.listdir(dir,10)
        for _, file in ipairs(list) do
            if not fs.isdir(file) then
                local name = fs.stem(file)
                scripts[name] = dir..name..".lua"
            end
        end
        moon.set_env_pack(dir, scripts)
    end

    for name, file in pairs(scripts) do
        local fn
        local content = moon.get_env(file)
        if content and #content > 0 then
            fn = load(content, "@"..file)
        else
            fn = assert(loadfile(file))
        end
        local t = fn(context)
        assert(type(t) == "table")
        context.scripts[name] = t
        reload.register(file, fn, t)

        for k,v in pairs(t) do
            local b = strbyte(k,1,1)
            if b>=65 and b <=90 and type(v) == "function" then -- if key is startswith upper case string
                assert(not command[k], string.format("error: command '%s' already exist when load '%s'.", k, file))
                command[k] = v
            end
        end
    end
end

local function _internal(context)
    command.hotfix = function (fixlist)
        for name, file in pairs(fixlist) do
            local ok, t = reload.reload(file)
            if ok then
                print(moon.name, "hotfix" , name, file)
                if not context.scripts[name] then
                    for k,v in pairs(t) do
                        local b = strbyte(k,1,1)
                        if b>=65 and b <=90 and type(v) == "function" then -- if key is startswith upper case string
                            assert(not command[k], string.format("error: command '%s' already exist when load '%s'.", k, file))
                            command[k] = v
                        end
                    end
                end
            else
                moon.error(moon.name, "hotfix failed" , t, name, file)
                break
            end
        end
    end

    context.batch_invoke = function(cmd, ...)
        for _, v in pairs(context.scripts) do
            local f = v[cmd]
            if f then
                f(...)
            end
        end
    end

    command.Init = function(...)
        context.batch_invoke("init", ...)
        return true
    end

    command.Start = function(...)
        context.batch_invoke("start", ...)
        return true
    end
end

local function start_hour_timer()
    local fn = command["OnHour"]
    if not fn then
        return
    end

    local MILLSECONDS_ONE_HOUR<const> = 3600000

    local hour = datetime.localtime(moon.time()).hour
    moon.async(function()
        while true do
            local diff = MILLSECONDS_ONE_HOUR - moon.now()%MILLSECONDS_ONE_HOUR + 1000
            moon.sleep(diff)
            local tm = datetime.localtime(moon.time())
            if hour == tm.hour then
                moon.error("not hour!")
            else
                hour = tm.hour
                local hourFn = command["OnHour"]
                if hourFn then
                    local ok, err = xpcall(hourFn, traceback, hour)
                    if not ok then
                        moon.error(err)
                    end
                end
                if hour == 0 then
                    local dayFn = command["OnDay"]
                    local ok, err = xpcall(dayFn, traceback, datetime.localday())
                    if not ok then
                        moon.error(err)
                    end
                end
            end
        end
    end)
end

local function xpcall_ret(ok, ...)
    if ok then
        return pack(...)
    end
    return pack(false, ...)
end

local function do_client_command(context, cmd, uid, req)
    local fn = command[cmd]
    if fn then
        local callok, res = xpcall(fn, traceback, uid, req)
        if not callok or res then
            res = res or 1 --server internal error
            context.send(uid,cmdcode.S2CErrorCode,{code = res})
        end
    else
        moon.error(moon.name, "receive unknown PTYPE_CLIENT cmd "..tostring(cmd) .. " " .. tostring(uid))
    end
end

return function(context, sname)

    sname = sname or moon.name

    if not context.scripts then
        context.scripts = {}
    end

    context.start_hour_timer = start_hour_timer

    _internal(context)

    load_scripts(context, sname)

    moon.dispatch("lua", function(sender, session, cmd, ...)
        local fn = command[cmd]
        if fn then
            if session ~= 0 then
                raw_send("lua", sender, "", xpcall_ret(xpcall(fn, traceback, ...)), session)
            else
                fn(...)
            end
        else
            moon.error(moon.name, "recv unknown cmd "..tostring(cmd))
        end
    end)

    moon.register_protocol({
        name = "client",
        PTYPE = constant.PTYPE_CLIENT,
        --default client message dispatch
        dispatch = function(msg)
            local header, buf = moon.decode(msg, "HB")
            --see: user service's forward
            local uid = unpack(header)
            local ok, cmd, data = pcall(protocol.decode, buf)
            if not ok then
                moon.error("protobuffer decode client message failed", cmd)
                moon.send("lua", context.gate, "Kick", uid)
                return
            end
            moon.async(do_client_command, context, cmd, uid, data)
        end
    })

    moon.register_protocol({
        name = "toclient",
        PTYPE = constant.PTYPE_TOCLIENT,
        dispatch = nil
    })

    context.send = function(uid, msgid, mdata)
        moon.raw_send('toclient', context.addr_gate, seri.packs(uid), protocol.encode(msgid, mdata))
    end

    context.send_user = function(uid, ...)
        moon.send("lua", context.addr_auth, "SendUser", uid, ...)
    end

    context.call_user = function(uid, ...)
        return moon.co_call("lua", context.addr_auth, "CallUser", uid, ...)
    end

    return direct_docmd, command
end


