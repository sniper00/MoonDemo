local fs = require("fs")

---游戏逻辑相关配置

local M = {
    PTYPE_C2S = 100,--- client to server
    PTYPE_S2C = 101,--- server to client
    PTYPE_SBC = 102,---server broadcast to client

    ---Entity Type Define
    TypeRoom = 1,
    TypeFood = 2,
    ---

    AoiEvent = {
        UpdateDir = 10,
        UpdateRadius = 11,
    },

    ---邮件操作类型
    MailOpt={
        --- 请求邮件列表
        ReqMailList = 1,
        --- 设置邮件已读
        SetMailRead = 2,
        --- 删除邮件
        DelMail = 3,
        --- 锁定邮件
        LockMail = 4,
        --- 领取邮件奖励
        GetReward = 5,
        --- 收藏邮件
        CollectMail = 6,
    },
}

function M.LogShrinkToFit(dir, nameprefix, maxcount)
    local logfiles = {}
    local log_filename_start = nameprefix
    local list = fs.listdir(dir)
    for _, file in ipairs(list) do
        if not fs.isdir(file) then
            local match = string.gmatch(fs.stem(file), "%a+_%d+")()
            if match and match == log_filename_start then
                table.insert(logfiles, file)
            end
        end
    end

    table.sort(logfiles)
    while #logfiles > maxcount do
        fs.remove(table.remove(logfiles, 1))
    end
end

return M
