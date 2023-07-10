local moon = require "moon"
local uuid = require "uuid"
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

function Mail.Shutdown()
    moon.quit()
    return true
end

---@return { [integer]: MailData }, ErrorCode?
function Mail.Load(uid, system)
    local maillist = UserMailList[uid]
    if maillist then
        return maillist
    end

    local lock = UserMailLock[uid]
    if not system and lock("count") > 0 then
        moon.error("Too many mail load requests uid=", uid)
        return {}, ErrorCode.OperationNotPermit
    end

    local scope_lock<close> = lock()
    local maillist = Database.LoadUserMail(context.addr_db_user, uid)
    if not maillist then
        return {}, ErrorCode.ServerInternalError
    end

    UserMailList[uid] = maillist

    print("load user mail", uid)

    return maillist
end

---@param uid integer
---@param mail MailData
---@param showOnly? boolean
function Mail.AddMail(uid, mail, showOnly)
    mail.id = uuid.next(GameDef.TypeMail)
    mail.flag = 0
    mail.ctime = moon.time()
    if showOnly then
        mail.flag = mail.flag | GameDef.MailFlag.ShowOnly
    end

    if not mail.rewards or #mail.rewards == 0 then
        mail.flag = mail.flag | GameDef.MailFlag.Taked
    end

    local maillist = Mail.Load(uid, true)
    maillist[mail.id] = mail

    Database.SaveUserMail(context.addr_db_user, uid, mail.id, mail)

    Mail.UpdateMail(uid, mail)

    return true
end

---@param uid integer
---@param mail MailData
function Mail.UpdateMail(uid, mail)
    Database.SaveUserMail(context.addr_db_user, uid, mail.id, mail)
    context.S2C(uid, CmdCode.S2CUpdateMail, {mail_list = {mail}})
end

---@param uid integer
---@param maillist MailData[]
function Mail.UpdateMailList(uid, maillist)
    context.S2C(uid, CmdCode.S2CUpdateMail, {mail_list = maillist})
end

---@param uid integer
---@param req C2SMailList
function Mail.C2SMailList(uid, req)
    local maillist, ec = Mail.Load(uid)
    if ec then
        return ec
    end
    context.S2C(uid, CmdCode.S2CMailList, {mail_list = maillist})
end

---@param uid integer
---@param req C2SMailRead
function Mail.C2SMailRead(uid, req)
    local maillist, ec = Mail.Load(uid)
    if ec then
        return ec
    end

    local mail = maillist[req.id]
    if not mail then
        return ErrorCode.ParamInvalid
    end

    mail.flag = mail.flag | GameDef.MailFlag.Read

    Mail.UpdateMail(uid, mail)
end

---@param uid integer
---@param req C2SMailLock
function Mail.C2SMailLock(uid, req)
    local maillist, ec = Mail.Load(uid)
    if ec then
        return ec
    end

    local mail = maillist[req.id]
    if not mail then
        return ErrorCode.ParamInvalid
    end

    mail.flag = mail.flag | GameDef.MailFlag.Locked

    Mail.UpdateMail(uid, mail)
end

---@param uid integer
---@param req C2SMailReward
function Mail.C2SMailReward(uid, req)
    local maillist, ec = Mail.Load(uid)
    if ec then
        return ec
    end

    local itemList = {}
    local updateList = {}
    for index, value in ipairs(req.mail_id_list) do
        local mail = maillist[value]
        if mail then
            mail.flag = mail.flag | GameDef.MailFlag.Read
            if (mail.flag & GameDef.MailFlag.Taked) == 0 and (mail.flag & GameDef.MailFlag.ShowOnly) == 0 then
                mail.flag = mail.flag | GameDef.MailFlag.Taked
                if mail.rewards then
                    for _, reward in ipairs(mail.rewards) do
                        itemList[#itemList+1] = reward
                    end
                end
            end
            updateList[#updateList+1] = mail
        end
    end

    if #itemList > 0 then
        context.send_user(uid, "Item.AddItemList", itemList)
    end

    if #updateList > 0 then
        Mail.UpdateMailList(uid, updateList)
    end
end

---@param uid integer
---@param req C2SMailMark
function Mail.C2SMailMark(uid, req)
    local maillist, ec = Mail.Load(uid)
    if ec then
        return ec
    end

    local mail = maillist[req.id]
    if not mail then
        return ErrorCode.ParamInvalid
    end

    mail.flag = mail.flag | GameDef.MailFlag.Marked

    Mail.UpdateMail(uid, mail)
end

---@param uid integer
---@param req C2SMailDel
function Mail.C2SMailDel(uid, req)
    local maillist, ec = Mail.Load(uid)
    if ec then
        return ec
    end

    local delList = {}
    for index, value in ipairs(req.mail_id_list) do
        local mail = maillist[value]
        if mail then
            mail.flag = mail.flag | GameDef.MailFlag.Read
            if (mail.flag & GameDef.MailFlag.Read)>0 and ((mail.flag & GameDef.MailFlag.Taked) > 0 or (mail.flag & GameDef.MailFlag.ShowOnly) > 0) then
                delList[#delList+1] = mail.id
                maillist[value] = nil
            end
        else
            moon.warn("Client attemp del unknown mail id:", value)
        end
    end

    if #delList > 0 then
        Database.DelUserMail(context.addr_db_user, uid, delList)
        context.S2C(uid, CmdCode.S2CMailDel, {mail_id_list = delList})
    end
end

return Mail