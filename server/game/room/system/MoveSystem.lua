local entitas = require("entitas")
local Components = require("room.Components")
local aoi = require("room.aoi")
local vector2 = require("common.vector2")

local Matcher = entitas.Matcher

local M = class("MoveSystem")

local dir_to_vec = vector2.new(0, 0)

---@param context room_context
function M:ctor(context)
    self.context = context
    self.idx = context.uid_index--用来根据id查询玩家entity
    self.cfg = context.conf
    --所有可以移动的entity
    self.movers = context.ecs_context:get_group(Matcher({Components.Mover}))
    aoi.on_enter = function ( ... )
        self:on_enter(...)
    end

    aoi.on_leave = function ( ... )
        self:on_leave(...)
    end
end

function M:on_enter( watcher, marker )
    local entity = self.idx:get_entity(watcher)
    if not entity then
        print("on_enter_failed not found watcher",watcher)
        return
    end

    local oe = self.idx:get_entity(marker)
    if not oe or oe:has(Components.Dead) then
        print("on_enter_failed not found marker, or marker dead",watcher)
        return
    end

    self.context.send(watcher, "S2CEnterView", {id = marker})
    if oe:has(Components.Mover) then
        self.context.send_component(watcher,oe,Components.Speed)
        self.context.send_component(watcher,oe,Components.Direction)
        self.context.send_component(watcher,oe,Components.Mover)
    elseif oe:has(Components.Food) then
        self.context.send_component(watcher,oe,Components.Food)
    end
    self.context.send_component(watcher,oe,Components.Position)
    self.context.send_component(watcher,oe,Components.Radius)
    self.context.send_component(watcher,oe,Components.BaseData)
    --print("EnterView", marker,"->",watcher)
end

function M:on_leave( watcher, marker )
    local entity = self.idx:get_entity(watcher)
    if entity then
        self.context.send(watcher,'S2CLeaveView',{id=marker})
        --print("LeaveView", marker,"->",watcher)
    else
        print("on_leave_failed not found",watcher)
    end
end

function M:update(...)
    --更新玩家位置
    local delta = ...
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

            local x, xout = math.clamp(pos.x + dir_to_vec.x, self.cfg.map.x, self.cfg.map.x + self.cfg.map.len)
            local y, yout = math.clamp(pos.y + dir_to_vec.y, self.cfg.map.y, self.cfg.map.y + self.cfg.map.len)

            if xout then dir_to_vec.x = 0 end
            if yout then dir_to_vec.y = 0 end

            e:replace(Components.Position, x, y)

            aoi.update(id, x, y)

            if xout or yout  then
                dir_to_vec:normalize()
                e:replace(Components.Direction,dir_to_vec.x,dir_to_vec.y)
            end
            --print("move",id,pos.x,pos.y, "->",x,y)
        end
    )

    local max_radius = 0
    local max_near = 0
    --计算玩家碰撞
    movers:foreach(
        function(e)
            if e:has(Components.Dead) then
                return
            end

            local id = e:get(Components.BaseData).id
            local radius = e:get(Components.Radius).value
            local pos = e:get(Components.Position)

            local near = aoi.get_aoi(id)
            if not near then
                return
            end

            if #near > max_near then
                max_near = #near
            end

            if radius > max_radius then
                max_radius = radius
            end

            local eat = 0
            for m, _ in pairs(near) do
                local ne = self.idx:get_entity(m)
                if ne and not ne:has(Components.Dead) then
                    local nradius = ne:get(Components.Radius).value
                    local npos = ne:get(Components.Position)
                    local mdist = math.abs(pos.x - npos.x) + math.abs(pos.y - npos.y)

                    if mdist < 2*(radius + nradius) then
                        local distance = math.sqrt((pos.x - npos.x)^2 + (pos.y - npos.y)^2 )

                        if nradius > max_radius then
                            max_radius = nradius
                        end

                        if distance < (radius + nradius) then
                            if radius < nradius then
                                break
                            elseif radius > nradius then
                                eat = eat + 1
                                ne:replace(Components.Dead)--玩家死亡，给玩家添加Dead Component
                            end
                        end
                    end
                end
            end

            if eat>0 then
                local weight = 0.01*eat
                e:replace(Components.Eat,weight)--更新玩家Eat组件，用来计算球体半径增加量

                local score = e:get(Components.Score).score
                e:replace(Components.Score,score + eat)
            end
        end
    )
    if aoi.max_view_count() > 200 then
        print("max view count", aoi.max_view_count())
    end

    if max_near > 50 then
        print("max near",max_near)
    end
end

return M
