local moon = require("moon")
local msgcode = require("common.msgcode")

---@type user_context
local context = ...

local models = context.models

---@type UserModel
local UserModel = models.UserModel

local CMD = {}

function CMD.Init(req)
    if not UserModel.IsOnLine() then
        local ok, res = xpcall(UserModel.Load,debug.traceback, req)
        if not ok then
            return ok, res
        end

        if not res then
            local errmsg = string.format("user auth failed, can not find user %d", req.uid)
            moon.error(errmsg)
            return false, errmsg
        end
        req.openid = res.openid
        context.uid = res.uid
    end
    return req.openid
end

function CMD.OffLine()
	if UserModel.IsMatching() then
        moon.co_call("lua", context.addr_center, "UnMatch", context.uid)
        UserModel.SetMatching(false)
    end

    local addr_room = UserModel.GetRoom()
    if addr_room then
        moon.co_call("lua", addr_room, "LeaveRoom", context.uid)
        UserModel.SetRoom(false)
    end
end

function CMD.Exit()
    local ok, err = xpcall(UserModel.Save, debug.traceback)
    if not ok then
        moon.error("user exit save db error", err)
    end
    moon.quit()
    return true
end

--请求匹配
function CMD.C2SMatch()
    --向匹配服务器请求
    assert(moon.co_call("lua", context.addr_center, "Match", context.uid, moon.sid()))
    UserModel.SetMatching(true)
    context.send(msgcode.S2CMatch,{res=true})
end

function CMD.MatchSuccess(addr_room)
    UserModel.SetMatching(false)
    context.addr_room = addr_room
    context.send(msgcode.S2CMatchSuccess,{res=true})
end

--房间一局结束
function CMD.GameOver(score)
    print("GameOver", score)
    UserModel.AddScore(score)
    context.addr_room = false
    context.send(msgcode.S2CGameOver,{score=score})
end

return CMD
