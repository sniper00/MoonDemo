# BallGame
多人简易版球球大作战，MoonNetLua的一个使用示例，同时演示如何在服务端使用Entitas lua(Entity Component System)

![image](https://github.com/sniper00/BallGame/raw/master/image/start.png)

![image](https://github.com/sniper00/BallGame/raw/master/image/game.png)

# 运行

- server 包含编译好的windows版可执行文件,可以直接双击运行。(如果没有安装vs2017,则需要vs2017运行环境VC_redist.x64.exe[可在这里下载](https://support.microsoft.com/en-us/help/2977003/the-latest-supported-visual-c-downloads)).


- client 请使用unity2018 启动执行第一个场景Prepare。

# 运行机器人
- ```./moon 2 ``` 运行机器人。 config.json 可以修改机器人数量

# 编译Server

[moon编译](https://github.com/sniper00/moon)

```
4. 编译

# 简介
服务端使用了 [Entitas lua版](https://github.com/sniper00/entitas-lua),有些改动，原版Matcher会匹配 任意组件发生变化的Entity,不太适合服务端编写，这里做了改动，Matcher感兴趣的组件发生变化的Entity.

## 参考资料
- [Inter-context communication in Entitas](https://github.com/sschmid/Entitas-CSharp/wiki/Inter-context-communication-in-Entitas-0.39.0)
- [How I build games with Entitas](https://github.com/sschmid/Entitas-CSharp/wiki/How-I-build-games-with-Entitas-%28FNGGames%29)

## Server

服务端开启了三个服务:
- service_gate 负责管理玩家网络连接，并转发玩家网络消息
- service_login 简易的认证功能，演示不同服务间通信
- service_game 游戏场景服务，主要演示使用ECS来编写服务端逻辑

## Client

客户端主要用来演示怎样使用 asyn/await 来处理网络消息，等异步操作。
```csharp
    //这段代码是客户端向服务器同步自己的方向，然后等待服务器返回消息更新自己的位置
    //异步操作都在一个函数中，使逻辑更加清晰
    async void CommandMove(float angle)
    {
        var msg =  await Network.Call<S2CCommandMove>(new C2SCommandMove { angle = angle });
        SetMePosition(new Vector2(msg.x, msg.y));
    }
```


