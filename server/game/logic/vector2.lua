local M = {}

M.__index = M

local FLOAT_MIN = 0.0000001

function M.new( x,y )
    local t = {x=x,y=y}
    setmetatable(t,M)
    return t
end

function M:set_x( x )
    self.x = x
end

function M:set_y( y )
    self.y = y
end

function M:from_angle( angle )
    self.x = math.cos( math.rad(angle))
    self.y = math.sin( math.rad(angle))
end

function M:len()
    return math.sqrt( self.x^2+self.y^2 )
end

function M:mul( delta )
    self.x=self.x*delta
    self.y=self.y*delta
end

function M:normalize()
    local n = self.x^2+self.y^2
    if n==1.0 then
        return
    end
    n = math.sqrt(n)
    if n<=FLOAT_MIN then
        return
    end
    n = 1.0/n
    self.x=self.x*n
    self.y=self.y*n
end

return M