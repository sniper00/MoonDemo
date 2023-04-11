# BallGame
多人简易版球球大作战，游戏服务器框架[moon](https://github.com/sniper00/moon)的一个使用示例。
主要演示
- 管理玩家网络连接
- 动态创建服务, 一个玩家一个service(LuaVM)
- redis数据库存储玩家数据
- 使用sharetable来处理游戏配表
- 客户端网络消息和服务器内部消息统一自动注册
- 游戏逻辑编写规范
- 服务器集群搭建
- 服务器管理后台示例
- 代码热更
- 代码注解
- 使用vscode lua-language-server 插件提供lua代码智能能提示
- 使用vscode LuaPanda 插件调试服务器代码

![image](https://github.com/sniper00/BallGame/raw/master/image/start.png)

![image](https://github.com/sniper00/BallGame/raw/master/image/game.png)

vscode打开server目录，安装[`lua-language-server`](https://marketplace.visualstudio.com/items?itemName=sumneko.lua)插件，即可获得代码提示能力，如果没有代码提示，在.vscode目录下, 创建或者修改settings.json, 添加
```json
{
    "Lua.workspace.library": [
        "./moon/lualib",
        "./moon/service/"
    ]
}
```

# Server结构介绍

Hub Server:
1. 提供服务后台管理, 服务器节点配置管理(支持动态开启新服)
2. 提供http server 和 telnet两种协议接口

Game Server开启了7种服务:
- node 处理hub的请求消息，常用于对接SDK和服务器后台管理
- cluster 服务器集群通信节点服务
- gate 负责管理玩家网络连接，并转发玩家网络消息到对应玩家服务
- auth 负责登录，创建、删除、离线加载、玩家服务
- center 负责玩家匹配逻辑，动态创建room服务
- user 玩家服务，一个服务对应一个玩家，处理玩家消息，管理玩家私有状态。 与其它玩家交互的消息转发到room服务。
- room 游戏场景服务，简易球球大作战玩法逻辑

目录结构
```
./
├── common/  #逻辑公共模块目录
│   ├── GameCfg.lua*
│   ├── GameDef.lua*
│   ├── LuaPanda.lua*
│   ├── cmdcode.lua*
│   ├── database.lua*
│   ├── init.lua*
│   ├── intellisense.lua* # 代码智能提示注解文件
│   ├── protocol.lua*
│   ├── protocol_pb.lua*
│   ├── setup.lua*
│   └── vector2.lua*
├── game/
│   ├── auth/ # 每个服务对应的逻辑脚本目录, 处理客户端消息和服务间交互消息。 在对应服务添加规范格式的lua脚本，会自动注册消息处理函数。
│   ├── center/
│   ├── gate/
│   ├── node/
│   ├── room/
│   ├── service_auth.lua*  # 服务初始化文件
│   ├── service_center.lua*
│   ├── service_gate.lua*
│   ├── service_hub.lua*
│   ├── service_node.lua*
│   ├── service_room.lua*
│   ├── service_user.lua*
│   └── user/
├── log/   # 游戏运行日志文件
├── main_game.lua* # game 进程启动文件
├── main_hub.lua*  # hub 进程启动文件
├── moon/          # moon源码
├── node.json*     # 节点通信配置文件，也用于cluster通信
├── robot/ 
│   └── robot.lua* # 机器人脚本，模拟玩家行为
├── serverconf.lua* # 服务器全局配置
├── start_game.sh*
├── start_hub.sh*
├── start_server.bat*
└── static/
    ├── table/  # 游戏配置表目录
    └── www/    # GM web 目录
```

# 编译Server

1. clone
```
git clone --recursive https://github.com/sniper00/MoonDemo.git
```

2. [参考moon编译](https://github.com/sniper00/moon#%E7%BC%96%E8%AF%91)

# 运行

- 安装redis 采用默认配置即可

- client 请使用unity2020 启动执行第一个场景Prepare。

- windows使用 `start_server.bat` 脚本运行。linux和macos使用`start_hub.sh`,`start_game.sh`依次启动。默认会自动运行机器人服务。[配表](https://github.com/sniper00/BallGame/blob/master/server/static/table/constant.lua) 可以修改机器人数量

- 简易后台管理
    - 方式一 Web http://127.0.0.1:8003/
    - 方式二 `telnet 127.0.0.1 8003`, 输入 `S1 help`

- 如需要自己部署，可以修改`node.json`中的ip地址

# 调试

- 安装vscode
- 安装 LuaPanda 插件
- 在需要调试的服务第一行添加代码(作为示例，center服务第一行添加了这行代码)
```lua
require("common.LuaPanda").start("127.0.0.1", 8818)
```
- [配置调试器](https://github.com/Tencent/LuaPanda/blob/master/Docs/Manual/access-guidelines.md#%E5%BC%80%E5%A7%8B%E8%B0%83%E8%AF%95)

![image](https://github.com/sniper00/BallGame/raw/master/image/setting.png)

- F5启动vscode-LuaPanda调试器
- 使用vscode,在该服务的逻辑代码出下断点
- 运行服务器，触发断点处的逻辑

![image](https://github.com/sniper00/BallGame/raw/master/image/debug.png)

# Client

客户端主要用来演示怎样使用 asyn/await 来处理网络消息，等异步操作。
```csharp
  var v = await Network.Call<S2CLogin>(UserData.GameSeverID, new C2SLogin { openid = userName.text });
  if (v.ok)
  {
      UserData.time = v.time;
      UserData.username = userName.text;
      await Network.Call<S2CMatch>(UserData.GameSeverID, new C2SMatch {});
      SceneManager.LoadScene("MatchWait");
  }
  else
  {
      MessageBox.Show("auth failed");
  }
```

```csharp
    //注册回调方式的网络消息
    Network.Register<NetMessage.S2CMatchSuccess>((res) =>
    {
        MessageBox.SetVisible(false);
        SceneManager.LoadScene("Game");
    });
```

# 开发流程


需要安装`python3`


## 添加新协议

修改server的protocol目录下的proto文件，协议命名规则`C2Sxxxx`表示客户端发送给服务器的消息；`S2Cxxxxx`,`SBCxxxxx` 表示服务器发送给客户端的消息，其中`SBC`表示广播消息，只是为了便于区分。

```
user.proto center.proto room.proto 对应各自服务的消息

common.proto 公共的proto定义

annotations.proto 只生成lua注解时使用

```

编写完成协议后，运行tools目录下的`moonfly.bat`,其它平台运行`python3 moonfly.py`

## 代码注解

protocol目录的文件都会生成lua注解，建议逻辑中多定义proto结构，提高开发速度，特别是复杂的对象，能达到 typescript 80% 的代码提示能力。对于关键数据可以用使用 verify_proto 进行验证，如需要存数据库的数据。

## User逻辑开发流程示例

### 定义协议

在 `protocol/user.proto` 中添加, 然后运行`tools/moonfly.bat`
```proto
//客户端发送
message C2SHello
{
    string hello = 1;
}

//服务器返回
message S2CWorld
{
    string world = 1;
}
```

### 编写逻辑

在`game/user/`目录下新建文件 "Hello.lua"

1. Lua逻辑脚本标准定义

```lua
local common = require "common"
local GameCfg = common.GameCfg --游戏配置
local ErrorCode = common.ErrorCode --逻辑错误码
local CmdCode = common.CmdCode --客户端通信消息码

---@type user_context
local context = ...
local scripts = context.scripts ---方便访问同服务的其它lua模块

---@class Hello ---模块代码注解
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
    --scripts.Item.AddItem(1,1,1)
end

return Hello
```

2. 编写逻辑(完整代码)

```lua
local moon = require("moon")
local common = require "common"
local GameCfg = common.GameCfg --游戏配置
local ErrorCode = common.ErrorCode --逻辑错误码
local CmdCode = common.CmdCode --客户端通信消息码

---@type user_context
local context = ...
local scripts = context.scripts ---方便访问同服务的其它lua模块

---@class Hello ---模块代码注解
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
    scripts.Item.AddItem(1,1,1)
end

---注册服务间通信的消息处理函数
---其它服务可以访问`context.send_user(uid, "Hello.DoSometing1", 1)`
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
```


