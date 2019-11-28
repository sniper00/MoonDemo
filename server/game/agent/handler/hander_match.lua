local moon = require("moon")
local msgcode = require("common.msgcode")

---@type agent_context
local context = ...

local CMD = {}

--请求匹配
function CMD.C2SMatch(_)
    --向匹配服务器请求
    assert(moon.co_call("lua", context.center, "Match", context.uid, moon.sid()))
    context.ismatching = true
    context.send(msgcode.S2CMatch,{res=true})
end

--匹配成功，主动告诉客户端
function CMD.MatchSuccess(room)
    --print("Match Success", room)
    context.room = room
    assert(moon.co_call("lua", room, "SetAddress", context.uid, moon.sid()))
    context.send(msgcode.S2CMatchSuccess,{res=true})
end

--房间一局结束
function CMD.GameOver(score)
    print("GameOver", score)
    context.room = false
    context.send(msgcode.S2CGameOver,{score=score})
end

return CMD
