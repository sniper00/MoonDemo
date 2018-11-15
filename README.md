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

需要用到laoi，请自行编译为lua动态库,把laoi：
1. 在服务器源码lualib-src目录下新建文件夹laoi
2. 把laoi目录的源码拷贝到新建的文件夹
3. 在服务器目录下的 premake.lua 最后新加
```lua
add_lua_module("./lualib-src/laoi", "aoi")
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

这段代码展示了更新玩家位置，并处理碰撞System逻辑：
```lua
local util = require("util")
local entitas = require("entitas")
local Components = require("Components")
local vector2 = require("vector2")
local ReactiveSystem = entitas.ReactiveSystem
local Matcher = entitas.Matcher
local GroupEvent = entitas.GroupEvent

local class = util.class

local M = class("MoveSystem", ReactiveSystem)

local dir_to_vec = vector2.new(0, 0)

function M:ctor(contexts, helper)
    M.super.ctor(self, contexts.input)
    self.context = contexts.game
    self.input_entity = contexts.input.input_entity--客户端网络消息承载entity
    self.idx = contexts.idx--用来根据id查询玩家entity
    --所有可以移动的entity
    self.movers = self.context:get_group(Matcher({Components.Mover}))
    self.aoi = helper.aoi--aoi模块
    self.aoi.on_enter = function ( ... )
        self:on_enter(...)
    end

    self.aoi.on_leave = function ( ... )
        self:on_leave(...)
    end
end

function M:get_trigger()
    return {
        {
            Matcher({Components.CommandUpdate}),--只处理 增加/更新 CommandUpdate Component操作的entity
            GroupEvent.ADDED | GroupEvent.UPDATE
        }
    }
end

function M:filter(entity)
    return entity:has(Components.CommandUpdate)
end

function M:on_enter( watcher, marker )
    local entity = self.idx:get_entity(watcher)
    if entity then
        if not entity:has(Components.EnterView) then
            entity:add(Components.EnterView,{marker})
            --print("on_enter_add",watcher,"->",marker)
        else
            local t = entity:get(Components.EnterView).ids
            table.insert(t, marker)
            --print("on_enter_update",watcher,"->",marker)
        end
    else
        --print("on_enter_failed not found",marker)
    end
end

function M:on_leave( watcher, marker )
    local entity = self.idx:get_entity(watcher)
    if entity then
        if not entity:has(Components.LeaveView) then
            entity:add(Components.LeaveView,{marker})
           -- print("on_leave_add",watcher,"->",marker)
        else
            local t = entity:get(Components.LeaveView).ids
            table.insert(t, marker)
           -- print("on_leave_update",watcher,"->",marker)
        end
    else
        --print("on_leave_failed not found",marker)
    end
end

function M:execute()
    --更新玩家位置
    local delta = self.input_entity:get(Components.CommandUpdate).delta
    local movers = self.movers.entities
    movers:foreach(
        function(e)
            local pos = e:get(Components.Position)
            local speed = e:get(Components.Speed)
            local id = e:get(Components.BaseData).id

            dir_to_vec:from_angle(e:get(Components.Direction).value)
            dir_to_vec:mul(speed.value*delta)

            local x = pos.x + dir_to_vec.x
            local y = pos.y + dir_to_vec.y

            e:replace(Components.Position, x, y)

            self.aoi.update_pos(id, "wm", x, y)
            --print("move",id,pos.x,pos.y, "->",x,y)
        end
    )

    self.aoi.update_message()

    --计算玩家碰撞
    movers:foreach(
        function(e)
            local pos = e:get(Components.Position)
            local id = e:get(Components.BaseData).id
            local radius = e:get(Components.Radius).value

            local near = self.aoi.get_aoi(id)
            if not near then
                return
            end
            local dead = false
            local eat = 0
            for m, v in pairs(near) do
                local ne = self.idx:get_entity(m)
                if ne then
                    local nid = ne:get(Components.BaseData).id
                    local npos = ne:get(Components.Position)
                    local nradius = ne:get(Components.Radius).value

                    local distance = math.sqrt((pos.x - npos.x) ^ 2 + (pos.y - npos.y) ^ 2)
                    --print("near", nid,distance)
                    if distance < (radius + nradius) then
                        if radius < nradius then
                            dead = true
                            break
                        else
                            eat = eat + 1
                            ne:add(Components.Dead)
                        end
                    end
                end
            end
            if dead then
                self.aoi.update_pos(id, "d", pos.x, pos.y)
                e:add(Components.Dead)--玩家死亡，给玩家添加Dead Component
            elseif eat>0 then
                local weight = 0.01*eat
                e:replace(Components.Eat,weight)--更新玩家Eat组件，用来计算球体半径增加量
            end
        end
    )
    self.aoi.update_message()
end

return M


```

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


