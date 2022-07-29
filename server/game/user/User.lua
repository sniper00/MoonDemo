local moon = require("moon")
local db = require("common.database")
local cmdcode = require("common.cmdcode")

---@type user_context
local context = ...
local scripts = context.scripts

local state = context.state

---@class User
local User = {}

function User.Load(req)
    local function fn()
        if context.model then
            return context.model
        end

        context.model = db.loaduser(context.addr_db_user, req.uid)

        local isnew = false
        if not context.model then
            if #req.openid==0 or req.pull then
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
        -- print_r(context.model)

        ---初始化自己数据
        context.batch_invoke("Init")
        ---初始化互相引用的数据
        context.batch_invoke("Start")

        if isnew then

        end
        return context.model
    end

    local ok, res = xpcall(fn, debug.traceback, req)
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
    return true
end

function User.Save()
    db.saveuser(context.addr_db_user, context.model.uid, context.model)
end

function User.Login(req)
    if req.pull then--服务器主动拉起玩家
        return context.model.openid
    end
    if state.online then
        context.batch_invoke("Offline")
    end
    context.batch_invoke("Online")
    return context.model.openid
end

function User.Logout()
    context.batch_invoke("Offline")
end

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
    if not state.online then
        return
    end

    print(context.uid, "offline")
    state.online = false

	if state.ismatching then
        state.ismatching = false
        moon.send("lua", context.addr_center, "Center.UnMatch", context.uid)
    end
end

function User.OnHour()
    -- body
end

function User.OnDay()
    -- body
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
    context.s2c(cmdcode.S2CUserData, context.model)
end

function User.C2SPing(req)
    req.stime = moon.time()
    context.s2c(cmdcode.S2CPong, req)
end

--请求匹配
function User.C2SMatch()
    if context.state.ismatching then
        return
    end

    context.state.ismatching = true
    --向匹配服务器请求
    local ok, err = moon.co_call("lua", context.addr_center, "Center.Match", context.uid, moon.id)
    if not ok then
        context.state.ismatching = false
        moon.error(err)
        return
    end
    context.s2c(cmdcode.S2CMatch,{res=true})
end

function User.MatchSuccess(addr_room)
    context.state.ismatching = false
    context.addr_room = addr_room
    context.s2c(cmdcode.S2CMatchSuccess,{res=true})
end

--房间一局结束
function User.GameOver(score)
    print("GameOver", score)
    context.model.score = context.model.score + score
    context.addr_room = 0
    context.s2c(cmdcode.S2CGameOver,{score=score})
    User.Save()
end

return User
