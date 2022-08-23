local FLOAT_MIN = 0.0000001

local M = {}

function M.normalize(v)
    local n = v.x^2+v.y^2
    if n==1.0 then
        return
    end
    n = math.sqrt(n)
    if n<=FLOAT_MIN then
        return
    end
    n = 1.0/n
    v.x=v.x*n
    v.y=v.y*n
    return v
end

function M.distance(v)
    return math.sqrt( v.x^2+v.y^2 )
end

function M.add(v1, v2 )
    return {x = v1.x + v2.x, y =  v1.y + v2.y}
end

function M.mul(v, delta )
    return {x = v.x*delta, y = v.y*delta}
end

return M