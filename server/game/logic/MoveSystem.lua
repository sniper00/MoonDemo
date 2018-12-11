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
    self.cfg = helper.cfg
    --所有可以移动的entity
    self.movers = self.context:get_group(Matcher({Components.Mover}))
    self.net = helper.net
    self.aoi = helper.aoi--aoi模块
    self.aoi.on_enter = function ( ... )
        self:on_enter(...)
    end

    self.aoi.on_leave = function ( ... )
        self:on_leave(...)
    end
end

local trigger = {
    {
        Matcher({Components.CommandUpdate}),--只处理 增加/更新 CommandUpdate Component操作的entity
        GroupEvent.ADDED | GroupEvent.UPDATE
    }
}

function M:get_trigger()
    return trigger
end

function M:filter(entity)
    return entity:has(Components.CommandUpdate)
end

function M:on_enter( watcher, marker )
    local entity = self.idx:get_entity(watcher)
    if entity then
        local oe = self.idx:get_entity(marker)
        if oe then
            self.net.send(watcher, "S2CEnterView", {id = marker})
            if oe:has(Components.Mover) then
                self.net.send_component(watcher,oe,Components.Speed)
                self.net.send_component(watcher,oe,Components.Direction)
                self.net.send_component(watcher,oe,Components.Mover)
            elseif oe:has(Components.Food) then
                self.net.send_component(watcher,oe,Components.Food)
            end

            self.net.send_component(watcher,oe,Components.BaseData)
            self.net.send_component(watcher,oe,Components.Position)
            self.net.send_component(watcher,oe,Components.Radius)
            --print("EnterView", marker,"->",watcher)
        end
    else
        print("on_enter_failed not found",marker)
    end
end

function M:on_leave( watcher, marker )
    local entity = self.idx:get_entity(watcher)
    if entity then
        self.net.send(watcher,'S2CLeaveView',{id=marker})
        --print("LeaveView", marker,"->",watcher)
    else
        print("on_leave_failed not found",marker)
    end
end

function M:execute()
    --更新玩家位置
    local delta = self.input_entity:get(Components.CommandUpdate).delta
    local movers = self.movers.entities
    movers:foreach(
        function(e)
            local pos = e:get(Components.Position)
            local dir = e:get(Components.Direction)
            local speed = e:get(Components.Speed)
            local id = e:get(Components.BaseData).id

            dir_to_vec:set_x(dir.x)
            dir_to_vec:set_y(dir.y)

            dir_to_vec:mul(speed.value*delta)

            local x = pos.x + dir_to_vec.x
            local y = pos.y + dir_to_vec.y

            local out_range = false

            if x>self.cfg.max_edge then
                x = self.cfg.max_edge
                out_range = true
                dir_to_vec.x = 0
            end

            if x<self.cfg.min_edge then
                x = self.cfg.min_edge
                out_range = true
                dir_to_vec.x = 0
            end

            if y>self.cfg.max_edge then
                y = self.cfg.max_edge
                out_range = true
                dir_to_vec.y = 0
            end

            if y<self.cfg.min_edge then
                y = self.cfg.min_edge
                out_range = true
                dir_to_vec.y = 0
            end

            e:replace(Components.Position, x, y)

            self.aoi.update_pos(id, "wm", x, y)

            if out_range  then
                dir_to_vec:normalize()
                e:replace(Components.Direction,dir_to_vec.x,dir_to_vec.y)
            end
            --print("move",id,pos.x,pos.y, "->",x,y)
        end
    )

    self.aoi.update_message()

    --计算玩家碰撞
    movers:foreach(
        function(e)
            if e:has(Components.Dead) then
                return
            end

            local pos = e:get(Components.Position)
            local id = e:get(Components.BaseData).id
            local radius = e:get(Components.Radius).value

            local near = self.aoi.get_aoi(id)
            if not near then
                return
            end

            local eat = 0
            for _, m in pairs(near) do
                local ne = self.idx:get_entity(m)
                if ne then
                    local nid = ne:get(Components.BaseData).id
                    local npos = ne:get(Components.Position)
                    local nradius = ne:get(Components.Radius).value
                    local distance = math.sqrt((pos.x - npos.x) ^ 2 + (pos.y - npos.y) ^ 2)
                    --print("near", nid,distance)
                    if distance < (radius + nradius) then
                        if radius < nradius then
                            break
                        elseif radius > nradius then
                            eat = eat + 1
                            ne:replace(Components.Dead)--玩家死亡，给玩家添加Dead Component
                        end
                    elseif distance > 10 then
                        self.aoi.leave_view(id,nid)
                    end
                end
            end

            if eat>0 then
                local weight = 0.01*eat
                e:replace(Components.Eat,weight)--更新玩家Eat组件，用来计算球体半径增加量
            end
        end
    )
    self.aoi.update_message()

    if self.aoi.cache_size() > 200 then
        print("max aoi cache", self.aoi.cache_size())
    end
end

return M
