function lerp(t, a, b)
  return t * (b - a) + a
end

---@param a integer
---@param b integer
---@return integer a % b, but returns b instead of 0
function mod_t(a, b)
  return (a - 1) % b + 1
end

--- rotate v by picotron angle (turns)
---@param v vec2
---@param a number
function vec_rot(v, a)
  local cos_a = cos(a)
  local sin_a = sin(a)
  return vec(v.x * cos_a - v.y * sin_a, v.x * sin_a + v.y * cos_a)
end

---@param a number picotron angle
function vec_from_angle(a)
  return vec(cos(a), sin(a)) 
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

function inv_norm_squared(v)
  local n_s = norm_squared(v)
  if n_s < 0.0001 then
    return 0
  end
  return 1/n_s
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

function dir_to_vec(d)
  if d == 0 then return vec(1, 0)
  elseif d == 1 then return vec(0, -1)
  elseif d == 2 then return vec(-1, 0)
  elseif d == 3 then return vec(0, 1)
  else error() end
end
