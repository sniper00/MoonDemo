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
