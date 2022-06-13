-- require("LuaPanda").start("127.0.0.1", 8818)
local moon = require("moon")
local seri = require("seri")
local buffer = require("buffer")
local setup = require("common.setup")
local protocol = require("common.protocol")
local cmdcode = require("common.cmdcode")
local constant = require("common.constant")

local bunpack = buffer.unpack

local mdecode = protocol.decode

local fwd_addr = cmdcode.forward

local id_to_name = protocol.name

local redirect = moon.redirect

local PTYPE_C2S = constant.PTYPE_C2S

---@class user_context:base_context
---@field public scripts user_scripts
---@field public model UserData @玩家数据结构protobuf文件描述
local context = {
    uid = 0,
    --- 玩家DB数据结构
    model = false,
    --- 内存数据结构
    state = {
        online = false,
        ---穿戴的装备
        ismatching = false,
    },
    scripts = {},
    ---other service address
    addr_gate = 0,
    addr_db_user = 0,
    addr_center = 0,
    addr_room = 0,
    addr_auth = 0,
}

local _, command = setup(context, "user")

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

    local header = seri.packs(context.uid)
    redirect(msg, header, address, PTYPE_C2S)
end

moon.dispatch("C2S",function(msg)
    local buf = moon.decode(msg, "B")
    local msgname = id_to_name(bunpack(buf, "<H"))
    if not command[msgname] then
        forward(msg, msgname)
    else
        local cmd, data = mdecode(buf)
        local fn = command[cmd]
        moon.async(function()
            local ok, res = xpcall(fn, debug.traceback, data)
            if not ok then
                moon.error(res)
                context.s2c(cmdcode.S2CErrorCode,{code = 1}) --server internal error
            elseif res then
                context.s2c(cmdcode.S2CErrorCode,{code = res})
            end
        end)
    end
end)

context.addr_gate = moon.queryservice("gate")
context.addr_db_user = moon.queryservice("db_user")
context.addr_center = moon.queryservice("center")
context.addr_auth = moon.queryservice("auth")

context.s2c = function(msgid, mdata)
    moon.raw_send('S2C', context.addr_gate, seri.packs(context.uid), protocol.encode(msgid, mdata))
end

print(context.addr_gate,context.addr_db_user )

moon.shutdown(function()
    --- rewrite default behavior: quit immediately
end)

---垃圾收集器间歇率控制着收集器需要在开启新的循环前要等待多久。 
---增大这个值会减少收集器的积极性。
---当这个值比 100 小的时候，收集器在开启新的循环前不会有等待。 
---设置这个值为 200 就会让收集器等到总内存使用量达到 之前的两倍时才开始新的循环。
---params: 垃圾收集器间歇率, 垃圾收集器步进倍率, 垃圾收集器单次运行步长“大小”
collectgarbage("incremental",120)
