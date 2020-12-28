
local dbutil = require("common.dbutil")

---@type user_context
local context = ...

---@class UserModel
local UserModel = {}

local MemModel = {
    online = false,
    ismatching = false,
}

local DBModel

local function Create(openid, uid)
    local t = {
        openid = openid,
        uid = uid,
        name = openid,
        level = 10,
        score = 0
    }
    return t
end

function UserModel.Load(req)
    if DBModel then
        return DBModel
    end

    DBModel = dbutil.loaduser(context.addr_db_user, req.uid)

    if not DBModel then
        if #req.openid==0 or req.isload then
            return
        end

        DBModel = Create(req.openid, req.uid)
    end

    --是否是服务器主动加载玩家
    if not req.isload then
        UserModel.OnLine()
    end

    UserModel.Init()

    return DBModel
end

function UserModel.Init()
    -- body
end

function UserModel.Save()
    dbutil.saveuser(context.addr_db_user, DBModel.uid, DBModel)
end

function UserModel.OnLine()
    MemModel.online = true
end

function UserModel.OffLine()
    MemModel.online = false
end

function UserModel.IsOnLine()
    return MemModel.online
end

function UserModel.IsMatching()
    return MemModel.ismatching
end

function UserModel.SetMatching(v)
    MemModel.ismatching = v
end

function UserModel.AddScore(v)
    DBModel.score = DBModel.score + v
    UserModel.Save()
end

return UserModel