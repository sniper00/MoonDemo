local moon = require("moon")
local db = require("common.database")
local cmdcode = require("common.cmdcode")

---@type user_context
local context = ...
local scripts = context.scripts

local state = context.state

---@class User
local User = {}

function User.Init()
    -- body
end

function User.Start()

end

function User.Online()
    state.online = true
    context.model.logintime = moon.time()

end

function User.Offline()
    print(context.uid,"offline")
    state.online = false

	if state.ismatching then
        state.ismatching = false
        moon.send("lua", context.addr_center, "Center.UnMatch", context.uid)
    end
end

function User.LoadUser(req)
    if context.model then
        return context.model
    end

    context.model = db.loaduser(context.addr_db_user, req.uid)

    local isnew = false
    if not context.model then
        if #req.openid==0 or req.isload then
            return
        end

        isnew = true

        ---create new user
        context.model = {
            openid = req.openid,
            uid = req.uid,
            name = req.openid,
            level = 10,
            score = 0
        }
    end
    print_r(context.model)

    ---初始化自己数据
    context.batch_invoke("Init")
    ---初始化互相引用的数据
    context.batch_invoke("Start")

    if isnew then

    end
    return context.model
end

function User.Save()
    db.saveuser(context.addr_db_user, context.model.uid, context.model)
end

function User.Load(req)
    if not state.online then
        local ok, res = xpcall(User.LoadUser, debug.traceback, req)
        if not ok then
            return ok, res
        end

        if not res then
            local errmsg = string.format("user init failed, can not find user %d", req.uid)
            moon.error(errmsg)
            return false, errmsg
        end
        req.openid = res.openid
        context.uid = res.uid

        --是否是服务器主动加载玩家
        if not req.pull then
            context.batch_invoke("online")
        end
    end
    return req.openid
end

function User.OnHour()
    -- body
end

function User.OnDay()
    -- body
end

function User.Disconnect()
    context.batch_invoke("offline")
end

function User.Exit()
    local ok, err = xpcall(User.Save, debug.traceback)
    if not ok then
        moon.error("user exit save db error", err)
    end
    moon.quit()
    return true
end

function User.C2SUserData()
    context.send(cmdcode.S2CUserData, context.model)
end

function User.C2SPing(req)
    req.stime = moon.time()
    context.send(cmdcode.S2CPong, req)
end

--请求匹配
function User.C2SMatch()
    --向匹配服务器请求
    assert(moon.co_call("lua", context.addr_center, "Center.Match", context.uid, moon.addr()))
    context.state.ismatching = true
    context.send(cmdcode.S2CMatch,{res=true})
end

function User.MatchSuccess(addr_room)
    context.state.ismatching = false
    context.addr_room = addr_room
    context.send(cmdcode.S2CMatchSuccess,{res=true})
end

--房间一局结束
function User.GameOver(score)
    print("GameOver", score)
    context.model.score = context.model.score + score
    context.addr_room = false
    context.send(cmdcode.S2CGameOver,{score=score})
    User.Save()
end

return User
