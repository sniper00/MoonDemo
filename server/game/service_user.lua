-- require("LuaPanda").start("127.0.0.1", 8818)
local moon = require("moon")
local seri = require("seri")
local buffer = require("buffer")
local common = require("common")

local protocol = common.protocol_pb
local setup = common.setup
local CmdCode = common.CmdCode
local GameDef = common.GameDef

local bunpack = buffer.unpack
local wfront = buffer.write_front

local mdecode = protocol.decode

local fwd_addr = CmdCode.forward

local id_to_name = protocol.name

local redirect = moon.redirect

local PTYPE_C2S = GameDef.PTYPE_C2S

---@class user_context:base_context
---@field scripts user_scripts
local context = {
    uid = 0,
    scripts = {},
    ---other service address
    addr_room = 0
}

local command = setup(context, "user")

local function forward(msg, msgname)
    local address
    local v = fwd_addr[msgname]
    if v then
        address = context[v]
    end

    if not address then
        moon.error("recv unknown message", msgname)
        return
    end

    redirect(msg, address, PTYPE_C2S)
end

moon.raw_dispatch("C2S",function(msg)
    local buf = moon.decode(msg, "B")
    local msgname = id_to_name(bunpack(buf, "<H"))
    if not command[msgname] then
        wfront(buf, seri.packs(context.uid))
        forward(msg, msgname)
    else
        local cmd, data = mdecode(buf)
        local fn = command[cmd]
        moon.async(function()
            local ok, res = xpcall(fn, debug.traceback, data)
            if not ok then
                moon.error(res)
                context.S2C(CmdCode.S2CErrorCode,{code = 1}) --server internal error
            elseif res then
                context.S2C(CmdCode.S2CErrorCode,{code = res})
            end
        end)
    end
end)

context.addr_gate = moon.queryservice("gate")
context.addr_db_user = moon.queryservice("db_user")
if moon.queryservice("db_game") > 0 then
    context.addr_db_user = moon.queryservice("db_game")
end
context.addr_center = moon.queryservice("center")
context.addr_auth = moon.queryservice("auth")
context.addr_mail = moon.queryservice("mail")

context.S2C = function(cmd_code, mtable)
    moon.raw_send('S2C', context.addr_gate, protocol.encode(context.uid, cmd_code, mtable))
end

moon.shutdown(function()
    --- rewrite default behavior: Avoid automatic service exits
end)

---垃圾收集器间歇率控制着收集器需要在开启新的循环前要等待多久。 
---增大这个值会减少收集器的积极性。
---当这个值比 100 小的时候，收集器在开启新的循环前不会有等待。 
---设置这个值为 200 就会让收集器等到总内存使用量达到 之前的两倍时才开始新的循环。
---params: 垃圾收集器间歇率, 垃圾收集器步进倍率, 垃圾收集器单次运行步长“大小”
collectgarbage("incremental",120)
