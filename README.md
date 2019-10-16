# BallGame
多人简易版球球大作战，游戏服务器[moon](https://github.com/sniper00/moon)的一个使用示例，同时演示如何在服务端使用Entitas lua(Entity Component System)

![image](https://github.com/sniper00/BallGame/raw/master/image/start.png)

![image](https://github.com/sniper00/BallGame/raw/master/image/game.png)

# 运行

- server 包含编译好的windows版可执行文件,可以直接`start_server.bat`运行。(如果没有安装vs2017,则需要vs2017运行环境VC_redist.x64.exe[可在这里下载](https://support.microsoft.com/en-us/help/2977003/the-latest-supported-visual-c-downloads)).


- client 请使用unity2018 启动执行第一个场景Prepare。

- server 默认会自动运行机器人服务。 config.json 可以修改机器人数量

# 编译Server

[moon编译](https://github.com/sniper00/moon)

# 简介
服务端使用了 [Entitas lua](https://github.com/sniper00/entitas-lua)

## 参考资料
- [Inter-context communication in Entitas](https://github.com/sschmid/Entitas-CSharp/wiki/Inter-context-communication-in-Entitas-0.39.0)
- [How I build games with Entitas](https://github.com/sschmid/Entitas-CSharp/wiki/How-I-build-games-with-Entitas-%28FNGGames%29)

## Server

服务端开启了4种服务:
- gate 负责管理玩家网络连接，并转发玩家网络消息到 agent
- login 登录服务
- agent 玩家服务，一个服务对应一个玩家，处理玩家消息。 与其它玩家交互的消息转发到room服务。
- room 游戏场景服务，主要演示使用ECS来编写服务端逻辑

## Client

客户端主要用来演示怎样使用 asyn/await 来处理网络消息，等异步操作。
```csharp
  var v = await Network.Call<S2CLogin>(UserData.GameSeverID, new C2SLogin { token = handshake });
  if (v.res == "200 OK")
  {
      UserData.username = userName.text;
      SceneManager.LoadScene("Game");
  }
  else
  {
      MessageBox.Show(v.res);
      Debug.Log(v.res);
  }
```


