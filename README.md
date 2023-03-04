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
- 使用vscode lua-language-server 插件提供lua代码智能能提示
- 使用vscode LuaPanda 插件调试服务器代码

![image](https://github.com/sniper00/BallGame/raw/master/image/start.png)

![image](https://github.com/sniper00/BallGame/raw/master/image/game.png)

如果lua-language-server没有代码提示
在.vscode目录下, 创建或者修改settings.json, 添加
```json
{
    "Lua.workspace.library": [
        "./moon/lualib"
    ]
}
```

# 编译Server

1. clone
```
git clone --recursive https://github.com/sniper00/BallGame.git --depth=1
```

2. [参考moon编译](https://github.com/sniper00/moon#%E7%BC%96%E8%AF%91)

# 运行

- 安装redis 采用默认配置即可

- client 请使用unity2018 启动执行第一个场景Prepare。

- 使用 `start_server` 脚本运行。默认会自动运行机器人服务。[配表](https://github.com/sniper00/BallGame/blob/master/server/static/table/constant.lua) 可以修改机器人数量

# 调试

- 安装vscode
- 安装 LuaPanda 插件
- 在需要调试的服务第一行添加代码(作为示例，room服务第一行添加了这行代码)
```lua
require("common.LuaPanda").start("127.0.0.1", 8818)
```
- [配置调试器](https://github.com/Tencent/LuaPanda/blob/master/Docs/Manual/access-guidelines.md#%E5%BC%80%E5%A7%8B%E8%B0%83%E8%AF%95)

![image](https://github.com/sniper00/BallGame/raw/master/image/setting.png)

- F5启动vscode-LuaPanda调试器
- 使用vscode,在该服务的逻辑代码出下断点
- 运行服务器，触发断点处的逻辑

![image](https://github.com/sniper00/BallGame/raw/master/image/debug.png)

## Server
Hub Server:
1. 提供服务后台管理, 服务器节点配置管理(支持动态开启新服)
2. 提供http server 和 telnet两种协议接口

Game Server开启了6种服务:
- node 服务器管理对接服务
- cluster 服务器集群通信节点服务
- gate 负责管理玩家网络连接，并转发玩家网络消息到对应玩家服务
- auth 负责登录，创建、删除、离线加载、玩家服务
- center 负责玩家匹配逻辑，动态创建room服务
- user 玩家服务，一个服务对应一个玩家，处理玩家消息。 与其它玩家交互的消息转发到room服务。
- room 游戏场景服务，简易球球大作战玩法逻辑

## Client

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


