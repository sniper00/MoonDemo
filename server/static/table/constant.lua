---@class constant
local constant = {
    room = {
        --- 匹配人数达到100就创建房间
        max_player_number = 100,
        --- 每局持续60s
        round_time = 60,
    },
    --- 登录99个机器人, 留下一个用unity登录
    robot_num = 99,
}

return constant