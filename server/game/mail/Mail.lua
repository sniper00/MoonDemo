local moon = require "moon"
local json = require "json"
local coqueue = require "moon.queue"
local common = require "common"
local GameDef= common.GameDef
local Database = common.Database
local GameCfg = common.GameCfg --游戏配置
local ErrorCode = common.ErrorCode --逻辑错误码
local CmdCode = common.CmdCode --客户端通信消息码

---@type mail_context
local context = ...
local scripts = context.scripts ---方便访问同服务的其它lua模块

local UserMailLock = setmetatable({},{__index =  function (t, k)
    local v = coqueue()
    t[k] = v
    return v
end})

local UserMailList = {}

---@class Mail
local Mail = {}

function Mail.Load(uid)
    local maillist = UserMailList[uid]
    if maillist then
        return maillist
    end

    local lock = UserMailLock[uid]
    if lock("count") > 0 then
        moon.error("Too many mail load requests uid=", uid)
        return
    end

    local scope_lock<close> = lock()
    local data = Database.LoadUserMail(context.addr_db_user, uid)
    if not data then
        return
    end

    maillist = {}
    assert(#data%2==0, tostring(uid))
    for i=1,#data,2 do
        ---@type Mail
        local mail = json.decode(data[i+1])
        maillist[tonumber(data[i])] = mail
    end

    UserMailList[uid] = maillist

    print("load user mail", uid)

    return maillist
end

function Mail.C2SMailList(uid, req)
    local maillist = Mail.Load(uid)
end

function Mail.C2SMailOpt(uid, req)
    local maillist = Mail.Load(uid)
end

return Mail