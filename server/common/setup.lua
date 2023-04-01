local moon = require("moon")
local hotfix = require("hotfix")
local fs = require("fs")
local seri = require("seri")
local datetime = require("moon.datetime")
local GameDef = require("common.GameDef")
local protocol = require("common.protocol_pb")
local CmdCode = require("common.CmdCode")
local GameCfg = require("common.GameCfg")

local string = string
local type = type
local strfmt = string.format
local traceback = debug.traceback

local unpack = moon.unpack
local pack = moon.pack
local raw_send = moon.raw_send

---@class base_context
---@field scripts table
---@field s2c fun(uid:integer, msgid:integer|string, mdata:table) @ 给玩家发送消息
---@field start_hour_timer fun() @ 开启整点定时器
---@field batch_invoke fun(fnname:string, ...) @批量调用所有脚本的函数
---@field send_user fun(uid:integer, cmd:string, ...) @给玩家服务发送消息
---@field call_user fun(uid:integer, cmd:string, ...) @调用玩家服务
---@field try_send_user fun(uid:integer, cmd:string, ...) @尝试给玩家服务发送消息

local command = {}

hotfix.addsearcher(function(file)
    local content = moon.env(file)
    return load(content,"@"..file), file
end)

local function load_scripts(context, sname)
    local dir = strfmt("game/%s/", sname)
    local scripts = moon.env_unpacked(dir)
    if not scripts then
        scripts = {}
        local list = fs.listdir(dir,10)
        for _, file in ipairs(list) do
            if not fs.isdir(file) then
                local name = fs.stem(file)
                scripts[name] = dir..name..".lua"
            end
        end
        moon.env_packed(dir, scripts)
    end

    for name, file in pairs(scripts) do
        local fn
        local content = moon.env(file)
        if content then
            fn = load(content, "@"..file)
        else
            fn = assert(loadfile(file))
        end
        local t = fn(context)
        assert(type(t) == "table")

        context.scripts[name] = t
        hotfix.register(file, fn, t)

        for k,v in pairs(t) do
            if type(v) == "function" then
                if string.sub(k,1,3) == "C2S" then
                    command[k] = v
                else
                    command[name.."."..k] = v
                end
            end
        end
    end
end

---@param context base_context
local function _internal(context)
    context.batch_invoke = function(cmd, ...)
        for _, v in pairs(context.scripts) do
            local f = v[cmd]
            if f then
                local ok, err = xpcall(f, traceback, ...)
                if not ok then
                    moon.error(err)
                end
            end
        end
    end

    command.hotfix = function (fixlist)
        for name, file in pairs(fixlist) do
            local ok, t = hotfix.update(file)
            if ok then
                print(moon.name, "hotfix" , name, file)
                if not context.scripts[name] then
                    for k,v in pairs(t) do
                        if string.sub(k,1,3) == "C2S" then
                            command[k] = v
                        else
                            command[name.."."..k] = v
                        end
                    end
                end
            else
                moon.error(moon.name, "hotfix failed" , t, name, file)
                break
            end
        end
    end

    command.reload = function (names)
        GameCfg.Reload(names)
        print(moon.name, "reload", table.concat(names," "))
    end

    command.Init = function(...)
        GameCfg.Load()
        context.batch_invoke("Init", ...)
        return true
    end

    command.Start = function(...)
        context.batch_invoke("Start", ...)
        return true
    end
end

---@param context base_context
local function start_hour_timer(context)
    local fn = command["OnHour"]
    if not fn then
        return
    end

    local MILLSECONDS_ONE_HOUR<const> = 3600000

    local hour = datetime.localtime(moon.time()).hour
    moon.async(function()
        while true do
            local diff = MILLSECONDS_ONE_HOUR - moon.now()%MILLSECONDS_ONE_HOUR + 1
            moon.sleep(diff)
            local tm = datetime.localtime(moon.time())
            if hour == tm.hour then
                moon.error("not hour!")
            else
                hour = tm.hour
                context.batch_invoke("OnHour", hour)
                if hour == 0 then
                    hour = tm.hour
                    context.batch_invoke("OnDay",  datetime.localday())
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
            context.s2c(uid,CmdCode.S2CErrorCode,{code = res})
        end
    else
        moon.error(moon.name, "receive unknown PTYPE_C2S cmd "..tostring(cmd) .. " " .. tostring(uid))
    end
end

return function(context, sname)

    sname = sname or moon.name

    if not context.scripts then
        context.scripts = {}
    end

    context.start_hour_timer = function ()
        start_hour_timer(context)
    end 

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
        name = "C2S",
        PTYPE = GameDef.PTYPE_C2S,
        --default client message dispatch
        israw = true,
        dispatch = function(msg)
            local header, buf = moon.decode(msg, "HB")
            --see: user service's forward
            local uid = unpack(header)
            local ok, cmd, data = pcall(protocol.decode, buf)
            if not ok then
                moon.error("protobuffer decode client message failed", cmd)
                moon.send("lua", context.gate, "Gate.Kick", uid)
                return
            end
            moon.async(do_client_command, context, cmd, uid, data)
        end
    })

    moon.register_protocol({
        name = "S2C",
        PTYPE = GameDef.PTYPE_S2C,
        dispatch = nil
    })

    moon.register_protocol({
        name = "SBC",
        PTYPE = GameDef.PTYPE_SBC,
        dispatch = nil
    })

    --- send message to client.
    context.s2c = function(uid, msgid, mdata)
        moon.raw_send('S2C', context.addr_gate, seri.packs(uid), protocol.encode(msgid, mdata))
    end

    --- send message to user-service.
    context.send_user = function(uid, ...)
        moon.send("lua", context.addr_auth, "Auth.SendUser", uid, ...)
    end

    --- send message to user-service and get results.
    context.call_user = function(uid, ...)
        return moon.call("lua", context.addr_auth, "Auth.CallUser", uid, ...)
    end

    context.try_send_user = function(uid, ...)
        moon.send("lua", context.addr_auth, "Auth.TrySendUser", uid, ...)
    end

    return command
end


