local moon = require("moon")
local common = require("common")
local CmdCode = common.CmdCode
local GameCfg = common.GameCfg
local Database = common.Database

---@type user_context
local context = ...
local scripts = context.scripts

local state = { ---内存中的状态
    online = false,
    ismatching = false
}

---@class User
local User = {}
function User.Load(req)
    local function fn()

        local data = scripts.UserModel.Get()
        if data then
            return data
        end

        data = Database.loaduser(context.addr_db_user, req.uid)

        local isnew = false
        if not data then
            if req.pull then
                return
            end

            isnew = true

            ---create new user
            data = {
                openid = req.openid,
                uid = req.uid,
                name = req.openid,
                level = 10,
                score = 0
            }
        end

        scripts.UserModel.Create(data)

        context.uid = req.uid
        ---初始化自己数据
        context.batch_invoke("Init", isnew)
        ---初始化互相引用的数据
        context.batch_invoke("Start")
        return data
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
    return true
end

function User.Login(req)
    if req.pull then--服务器主动拉起玩家
        return scripts.UserModel.Get().openid
    end
    if state.online then
        context.batch_invoke("Offline")
    end
    context.batch_invoke("Online")
    return scripts.UserModel.Get().openid
end

function User.Logout()
    context.batch_invoke("Offline")
    return true
end

function User.Init()
    GameCfg.Load()
end

function User.Start()

end

function User.Online()
    state.online = true
    scripts.UserModel.MutGet().logintime = moon.time()
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
    local ok, err = xpcall(scripts.UserModel.Save, debug.traceback)
    if not ok then
        moon.error("user exit save db error", err)
    end
    moon.quit()
    return true
end

function User.C2SUserData()
    context.S2C(CmdCode.S2CUserData, scripts.UserModel.Get())
end

function User.C2SPing(req)
    req.stime = moon.time()
    context.S2C(CmdCode.S2CPong, req)
end

--请求匹配
function User.C2SMatch()
    if state.ismatching then
        return
    end

    state.ismatching = true
    --向匹配服务器请求
    local ok, err = moon.call("lua", context.addr_center, "Center.Match", context.uid, moon.id)
    if not ok then
        state.ismatching = false
        moon.error(err)
        return
    end
    context.S2C(CmdCode.S2CMatch,{res=true})
end

function User.MatchSuccess(addr_room, roomid)
    state.ismatching = false
    context.addr_room = addr_room
    state.roomid = roomid
    context.S2C(CmdCode.S2CMatchSuccess,{res=true})
end

--房间一局结束
function User.GameOver(score)
    print("GameOver, add score", score)
    local data = scripts.UserModel.MutGet()
    data.score = data.score + score
    context.addr_room = 0
    context.S2C(CmdCode.S2CGameOver,{score=score})
end

function User.AddScore(count)
    local data = scripts.UserModel.MutGet()
    data.score = data.score + count
    return true
end

return User
