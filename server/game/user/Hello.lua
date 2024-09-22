local moon = require("moon")
local common = require "common"
local GameCfg = common.GameCfg --游戏配置
local ErrorCode = common.ErrorCode --逻辑错误码
local CmdCode = common.CmdCode --客户端通信消息码

---@type user_context
local context = ...
local scripts = context.scripts ---方便访问同服务的其它lua模块

---@class Hello
local Hello = {}

---这里初始化本模块相关的数据
function Hello.Init()
    -- local DB = scripts.UserModel.Get()
    -- if not DB.hello then
    --     DB.hello = {
    --         a = 1,
    --         b = 2
    --     }
    -- end
end

---这里可以访问其它模块,做更多初始化工作
function Hello.Start()
    scripts.Item.AddItem(10001,1,1)
    local ok, err = moon.call("lua", context.addr_mail, "Mail.AddMail", context.uid, {
		mail_key = "hello_mail",
		flag = 0,
		rewards = {
			{id = 10001, count = 1},
			{id = 10002, count = 2},
		},
	})
    assert(ok, err)
end

---注册服务间通信的消息处理函数
---其它服务可以访问`context.send_user(uid, "Hello.DoSometing1", 1)`
---其它服务可以访问`local res = context.call_user(uid, "Hello.DoSometing1", 1)`
function Hello.DoSometing1(params)

end

---注册服务间通信的消息处理函数
---其它服务可以访问`local res = context.call_user(uid, "Hello.DoSometing1", 1)`
function Hello.DoSometing2()
    return "OK"
end

---注册客户端消息处理函数
---@param req C2SHello
function Hello.C2SHello(req)
    local cfg = GameCfg.item[1]
    if not cfg then
        return ErrorCode.ItemNotExist ---直接返回错误码, 会给玩家发送 S2CErrorCode 消息
    end
    context.S2C(CmdCode.S2CWorld, {world=req.hello}) ---给客户端发送消息
end

return Hello