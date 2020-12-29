# BallGame
多人简易版球球大作战，游戏服务器框架[moon](https://github.com/sniper00/moon)的一个使用示例。
主要演示
- 如何管理玩家网络连接
- 如何动态创建服务
- 如何使用redis数据库存储玩家数据
- 使用vscode LuaPanda 插件调试服务器代码

![image](https://github.com/sniper00/BallGame/raw/master/image/start.png)

![image](https://github.com/sniper00/BallGame/raw/master/image/game.png)

# 编译Server

1. clone
```
git clone --recursive https://github.com/sniper00/BallGame.git --depth=1
```

2. [参考moon编译](https://github.com/sniper00/moon#%E7%BC%96%E8%AF%91)

# 运行

- 安装redis 采用默认配置即可

- client 请使用unity2018 启动执行第一个场景Prepare。

- 使用 `start_server` 脚本运行。默认会自动运行机器人服务。`server/config.json` 可以修改机器人数量

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

服务端开启了4种服务:
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


