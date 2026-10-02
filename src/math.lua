
---@param a integer
---@param b integer
---@return integer a % b, but returns b instead of 0
function mod_t(a, b)
  return (a - 1) % b + 1
end

function vec_equals(v, u)
  return v.x == u.x and v.y == u.y 
end

function norm_squared(v)
  return v.x * v.x + v.y * v.y
end

function norm(v)
  return math.sqrt(v.x * v.x + v.y * v.y)
end

function normalize(v)
  local norm_sq = norm_squared(v)
  if norm_sq < 0.0001 then
    return 0
  end
  return v / math.sqrt(norm_sq)
end

function dot(v, u)
  return v.x * u.x + v.y * u.y
end
