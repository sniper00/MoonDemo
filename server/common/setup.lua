local moon            = require("moon")
local json            = require("json")
local hotfix          = require("hotfix")
local fs              = require("fs")
local seri            = require("seri")
local datetime        = require("moon.datetime")
local common          = require("common")
local profile         = require("coroutine.profile")
local GameDef         = common.GameDef
local protocol        = common.protocol
local CmdCode         = common.CmdCode
local GameCfg         = common.GameCfg

local string          = string
local type            = type
local strfmt          = string.format
local traceback       = debug.traceback

local unpack_one      = seri.unpack_one
local pack            = moon.pack
local raw_send        = moon.raw_send

local command         = {}

local profiler_record = {}

hotfix.addsearcher(function(file)
    local content = moon.env(file)
    return load(content, "@" .. file), file
end)

local function load_scripts(context, sname)
    local dir = strfmt("game/%s/", sname)
    local scripts = moon.env_unpacked(dir)
    if not scripts then
        scripts = {}
        local list = fs.listdir(dir, 10)
        for _, file in ipairs(list) do
            if not fs.isdir(file) then
                local name = fs.stem(file)
                scripts[name] = dir .. name .. ".lua"
            end
        end
        moon.env_packed(dir, scripts)
    end

    for name, file in pairs(scripts) do
        local fn
        local content = moon.env(file)
        if content then
            fn = load(content, "@" .. file)
        else
            fn = assert(loadfile(file))
        end
        local t = fn(context)
        assert(type(t) == "table", "script must return a table: " .. file)

        context.scripts[name] = t
        hotfix.register(file, fn, t)

        for k, v in pairs(t) do
            if type(v) == "function" then
                if string.sub(k, 1, 3) == "C2S" then
                    command[k] = v
                else
                    command[name .. "." .. k] = v
                end
            end
        end
    end
end

---@param context base_context
local function start_hour_timer(context)
    local fn = command["OnHour"]
    if not fn then
        return
    end

    local MILLSECONDS_ONE_HOUR <const> = 3600000

    local hour = datetime.localtime(moon.time()).hour
    moon.async(function()
        while true do
            local diff = MILLSECONDS_ONE_HOUR - moon.now() % MILLSECONDS_ONE_HOUR + 100
            moon.sleep(diff)
            local tm = datetime.localtime(moon.time())
            if hour == tm.hour then
                moon.error("not hour!")
            else
                hour = tm.hour
                local _ = context.batch_invoke("OnHour", hour)
                if hour == 0 then
                    hour = tm.hour
                    local _ = context.batch_invoke("OnDay", datetime.localday())
                end
            end
        end
    end)
end

local dynamic_send_wrap = setmetatable({}, { __mode = "kv" })
local dynamic_call_wrap = setmetatable({}, { __mode = "kv" })
local function wrap_send_or_call(who, is_send)
    local M = { memo = "" }
    setmetatable(M, {
        __index = function(self, k)
            if #self.memo == 0 then
                self.memo = self.memo .. k .. "."
            else
                self.memo = self.memo .. k
            end
            return M
        end,
        __call = function(self, ...)
            local receiver = who
            local cmd = M.memo
            M.memo = ""
            if is_send then
                return moon.send('lua', receiver, cmd, ...)
            else
                return moon.call('lua', receiver, cmd, ...)
            end
        end
    })
    return M
end

local function _internal(context)
    ---@class base_context
    ---@field scripts table
    ---@field addr_gate integer
    ---@field addr_auth integer
    ---@field addr_center integer
    ---@field addr_db_user integer
    ---@field addr_db_server integer
    ---@field addr_db_openid integer
    ---@field addr_mail integer
    local base_context = context

    ---@alias services 
    --- | gate_scripts 
    --- | auth_scripts 
    --- | user_scripts 
    --- | center_scripts 
    --- | room_scripts 
    --- | mail_scripts

    --- Create a dynamic proxy for sending messages to a service (fire-and-forget).
    --- The returned proxy supports chained method calls, e.g., SEND("user_scripts").Module.Function(...)
    --- Uses caching to avoid recreating wrappers for the same service.
    ---@generic T: services
    ---@param name `T` Service name (e.g., "user_scripts", "gate_scripts")
    ---@param addr integer? Optional service address, if nil will query by name
    ---@return T @ A proxy object that can chain method calls and send messages
    function base_context.SEND(name, addr)
        name = "addr_" .. string.gsub(name, "_scripts", "")
        local v = addr and dynamic_send_wrap[addr] or dynamic_send_wrap[name]
        if not v then
            if not addr then
                addr = context[name]
            end
            v = wrap_send_or_call(addr, true)
            if addr then
                dynamic_send_wrap[addr] = v
            else
                dynamic_send_wrap[name] = v
            end
        end
        return v
    end

    --- Create a dynamic proxy for calling a service and waiting for response.
    --- The returned proxy supports chained method calls, e.g., CALL("user_scripts").Module.Function(...)
    --- Uses caching to avoid recreating wrappers for the same service.
    ---@generic T: services
    ---@param name `T` Service name (e.g., "user_scripts", "gate_scripts")
    ---@param addr integer? Optional service address, if nil will query by name
    ---@return T @ A proxy object that can chain method calls and await responses
    function base_context.CALL(name, addr)
        name = "addr_" .. string.gsub(name, "_scripts", "")
        local v = addr and dynamic_call_wrap[addr] or dynamic_call_wrap[name]
        if not v then
            if not addr then
                addr = context[name]
            end
            v = wrap_send_or_call(addr, false)
            if addr then
                dynamic_call_wrap[addr] = v
            else
                dynamic_call_wrap[name] = v
            end
        end
        return v
    end

    setmetatable(base_context, {
        __index = function(t, key)
            if string.sub(key, 1, 5) == "addr_" then
                local addr = moon.queryservice(string.sub(key, 6))
                if addr == 0 then
                    error("Can not found service: " .. tostring(key))
                end
                t[key] = addr
                return addr
            end
            return nil
        end
    })

    if not base_context.scripts then
        base_context.scripts = {}
    end

    --- 开启整点定时器
    function base_context.start_hour_timer()
        start_hour_timer(context)
    end

    --- 批量调用所有脚本的函数, 如果发生错误, 会打印错误信息
    function base_context.batch_invoke(cmd, ...)
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

    --- 批量调用所有脚本的函数, 如果发生错误, 抛出异常
    function base_context.batch_invoke_throw(cmd, ...)
        for _, v in pairs(context.scripts) do
            local f = v[cmd]
            if f then
                f(...)
            end
        end
    end

    --- send message to client.
    function base_context.S2C(uid, cmd_code, mtable)
        moon.raw_send('S2C', context.addr_gate, protocol.encode(uid, cmd_code, mtable))
    end

    --- 给玩家服务发送消息,如果玩家不在线,会加载玩家
    function base_context.send_user(uid, ...)
        moon.send("lua", context.addr_auth, "Auth.SendUser", uid, ...)
    end

    --- 调用玩家服务,如果玩家不在线,会加载玩家
    function base_context.call_user(uid, ...)
        local session = moon.next_sequence()
        moon.send("lua", context.addr_auth, "Auth.CallUser", moon.id, session, uid, ...)
        return moon.wait(session)
    end

    --- 尝试给玩家服务发送消息,如果玩家不在线,消息会被忽略
    function base_context.try_send_user(uid, ...)
        moon.send("lua", context.addr_auth, "Auth.TrySendUser", uid, ...)
    end

    command.hotfix = function(fixlist)
        for name, file in pairs(fixlist) do
            local ok, t = hotfix.update(file)
            if ok then
                print(moon.name, "hotfix", name, file)
                for k, v in pairs(t) do
                    if string.sub(k, 1, 3) == "C2S" then
                        command[k] = v
                    else
                        command[name .. "." .. k] = v
                    end
                end
            else
                moon.error(moon.name, "hotfix failed", t, name, file)
                break
            end
        end
    end

    command.reload = function(names)
        GameCfg.Reload(names)
        print(moon.name, "reload", table.concat(names, " "))
    end

    command._profile = function()
        return profiler_record
    end

    command.Init = function(...)
        GameCfg.Load()
        base_context.batch_invoke_throw("Init", ...)
        return true
    end

    command.Start = function(...)
        base_context.batch_invoke_throw("Start", ...)
        return true
    end
end

local function xpcall_ret(ok, ...)
    if ok then
        return pack(...)
    end
    return pack(false, ...)
end

local function do_client_command(context, cmd, uid, req)
    profile.start()
    local fn = command[cmd]
    if fn then
        local ok, res = xpcall(fn, traceback, uid, req)
        if not ok then
            moon.error(res)
            context.S2C(uid, CmdCode.S2CErrorCode, { code = 1 }) -- server internal error
        else
            if res and res > 0 then
                context.S2C(uid, CmdCode.S2CErrorCode, { code = res })
            end
        end
    else
        moon.error(moon.name, "receive unknown PTYPE_C2S cmd " .. tostring(cmd) .. " " .. tostring(uid))
    end
    local v = profiler_record[cmd]
    if not v then
        v = { count = 0, cost = 0 }
        profiler_record[cmd] = v
    end
    v.count = v.count + 1
    v.cost = v.cost + profile.stop()
end

return function(context, sname)
    sname = sname or moon.name

    _internal(context)

    load_scripts(context, sname)

    moon.dispatch("lua", function(sender, session, cmd, ...)
        profile.start()
        local fn = command[cmd]
        if fn then
            if session ~= 0 then
                raw_send("lua", sender, xpcall_ret(xpcall(fn, traceback, ...)), session)
            else
                fn(...)
            end
        else
            moon.error(moon.name, "recv unknown cmd " .. tostring(cmd))
            if session ~= 0 then
                raw_send("lua", sender, xpcall_ret(false, moon.name .. " recv unknown cmd " .. tostring(cmd)), session)
            end
        end
        local v = profiler_record[cmd]
        if not v then
            v = { count = 0, cost = 0 }
            profiler_record[cmd] = v
        end
        v.count = v.count + 1
        v.cost = v.cost + profile.stop()
    end)

    moon.register_protocol({
        name = "C2S",
        PTYPE = GameDef.PTYPE_C2S,
        --default client message dispatch
        israw = true,
        dispatch = function(msg)
            local buf = moon.decode(msg, "B")
            --see: user service's forward
            local uid = unpack_one(buf, true)
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

    return command
end
