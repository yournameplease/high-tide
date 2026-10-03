local PLAYER_HALF_H = 0.7
local PLAYER_HALF_W = 0.2
local PLAYER_FRIC = 0.96
local PLAYER_STROKE_VEL = 0.2
local PLAYER_STROKE_TIME = 45

local WATER_X_AMP = 0.0004
local WATER_Y_AMP = 0.0004
local WATER_X_FREQ = 127
local WATER_Y_FREQ = 63
local WATER_X_PHASE = 150

-- todo diagonal bits to push against wall
local PLAYER_FEET_POINTS = {
  vec(-PLAYER_HALF_H, -PLAYER_HALF_W), 
  vec(-PLAYER_HALF_H, PLAYER_HALF_W),
}
local PLAYER_BODY_POINTS = {
  vec(0, -PLAYER_HALF_W), 
  vec(0, PLAYER_HALF_W),
}
local PLAYER_HEAD_POINTS = {
  vec(PLAYER_HALF_H * .5, -PLAYER_HALF_W), 
  vec(PLAYER_HALF_H, 0),
  vec(PLAYER_HALF_H * .5, PLAYER_HALF_W),
}
local PLAYER_ALL_POINTS = {}
for _,p in ipairs(PLAYER_FEET_POINTS) do add(PLAYER_ALL_POINTS, p) end
for _,p in ipairs(PLAYER_BODY_POINTS) do add(PLAYER_ALL_POINTS, p) end
for _,p in ipairs(PLAYER_HEAD_POINTS) do add(PLAYER_ALL_POINTS, p) end


---@class Player
---@field pos vec2
---@field t number
---@field dir integer quarter turns from angle 0. (0-3)
local Player = {}
Player.__index = Player

local function player_new(x, y, dir)
  local self = setmetatable({
    pos = vec(x, y),
    vel = vec(0, 0),
    t = 0,
    stroke_t = 0,
    dir = 0,
  }, Player)

  return self
end


---@class World
---@field bg userdata
---@field tiles userdata
---@field fg userdata
---@field t integer
---@field player Player

local World = {}
World.__index = World

local world = {}


function world.new(map_path)
  local self = setmetatable({}, World)

  local m = fetch(map_path)
  self.bg = m[1].bmp
  self.tiles = m[2].bmp
  self.fg = m[3].bmp

  self.player = player_new(8, 4, 0)

  self.t = 0

  return self
end

function World:update()
  self.t = self.t + 1
  
  local water_vel = vec(
    WATER_X_AMP * sin(self.t / WATER_X_FREQ + WATER_X_PHASE),
    WATER_Y_AMP * sin(self.t / WATER_Y_FREQ)
  )
  
  do -- player movement
    local p = self.player
    local any_move = false

    if p.stroke_t <= 0 then
      local dx = 0
      local dy = 0
      if (btn(0))then any_move = true dx = dx - 1 end
      if (btn(1))then any_move = true dx = dx + 1 end
      if (btn(2))then any_move = true dy = dy - 1 end
      if (btn(3))then any_move = true dy = dy + 1 end

      local new_dir
      if abs(dx) >= abs(dy) then
        if dx >= 0 then new_dir = 0 else new_dir = 2 end
      else
        if dy >= 0 then new_dir = 3 else new_dir = 1 end
      end

      -- don't turn around hard
      if abs(p.dir - new_dir) == 2 then
        new_dir = p.dir
      end

      p.dir = new_dir

      if any_move then
        p.stroke_t = PLAYER_STROKE_TIME
        p.vel = p.vel + PLAYER_STROKE_VEL * normalize(vec(dx, dy))
      end
    else
      p.stroke_t = p.stroke_t - 1
    end

    self:do_player_move(p, p.vel.x, p.vel.y)
    if norm_squared(p.vel) > 0.0001 then
       p.t =  p.t + 1
    else
       p.t =  p.t // 2
    end

    -- less sway if already moving fast
    p.vel = p.vel + water_vel-- * (1 + inv_norm_squared(p.vel))
    p.vel = p.vel * PLAYER_FRIC
  end
end

function World:draw()
  cls(COLORS.BG)

  local p = self.player

  local p_pos = p.pos * TILE_FACTOR
  local cam_x = p_pos.x - CENTER_X
  local cam_y = p_pos.y - CENTER_Y
  camera(cam_x, cam_y)


  map(self.bg, 0, 0, 0 - p.pos.x / 10)
  map(self.tiles, 0, 0)

  local hflip = false
  local vflip = false
  local index = 16 + (p.t //20 ) % 4
  if p.dir == 1 or p.dir == 3 then index = index + 4 end
  if p.dir == 2 then hflip = true end
  if p.dir == 3 then vflip = true end
  spr(0x30000 | index, p_pos.x,  p_pos.y + ( p.t//20%2),  hflip, vflip)

  do -- debug points
    for i, o in ipairs(PLAYER_ALL_POINTS) do
      local step = vec_rot(o, p.dir/4)
      local tile_pos = p_pos + step * TILE_FACTOR
      pset(tile_pos.x, tile_pos.y, 8)
    end
  end
  

  map(self.fg, 0, 0, p.pos.x / 10)

  camera()
end

function World:try_move_player(p, dx, dy, dir, check_feet)

  local new_pos = p.pos + vec(dx, dy)
  
  local is_solid = false
  local is_push = false
  local all_air = true
  local push_dir
  local is_breathing = false
  for i, o in ipairs(PLAYER_BODY_POINTS) do
    local step = vec_rot(o, dir/4)
    local tile_pos = new_pos + step
    local tile = self.tiles:get(tile_pos.x, tile_pos.y)

    if fget(tile, 0) then
      is_solid = true
    end
    if not fget(tile, 1) then
      all_air = false
    end
  end
  for i, o in ipairs(PLAYER_FEET_POINTS) do
    local step = vec_rot(o, dir/4)
    local tile_pos = new_pos + step
    local tile = self.tiles:get(tile_pos.x, tile_pos.y)

    if fget(tile, 0) then
      if check_feet then
        is_solid = true
      end
    end
    if not fget(tile, 1) then
      all_air = false
    end
  end
  for i, o in ipairs(PLAYER_HEAD_POINTS) do
    local step = vec_rot(o, dir/4)
    local tile_pos = new_pos + step
    local tile = self.tiles:get(tile_pos.x, tile_pos.y)
    if fget(tile, 0) then
      if i == 1 or i == 3 then
        if not is_push then
          is_push = true
        else
          is_solid = true
        end
      else
        is_solid = true
      end
    end
    if fget(tile, 1) then
      is_breathing = true
    end
    if not fget(tile, 1) then
      all_air = false
    end
  end

  if is_solid or all_air then
    return
  end

  p.pos = new_pos
  p.dir = dir
end

function World:do_player_move(p, dx, dy)
  if dx ~= 0 or dy ~= 0 then
    local check_feet = false -- makes turning against walls nicer

    local vel = vec(dx, dy)
    local dir_vec = dir_to_vec(p.dir)
    -- don't turn around hard
    if dot(vel, dir_vec) < 0 then
      dx = dx * 0.5
      dy = dy * 0.5
      check_feet = true
    end

    self:try_move_player(p, dx, 0, p.dir, check_feet)
    self:try_move_player(p, 0, dy, p.dir, check_feet)
  end

  local push_dir
  local is_push = false
  for i, o in ipairs(PLAYER_HEAD_POINTS) do
    local step = vec_rot(o, p.dir/4)
    local tile_pos = p.pos + step
    local tile = self.tiles:get(tile_pos.x, tile_pos.y)
    if fget(tile, 0) then
      if i == 1 or i == 3 then
        is_push = true
        if i == 1 then
          push_dir = (p.dir - 1) % 4
        elseif i == 3 then
          push_dir = (p.dir + 1) % 4
        end
      end
    end
  end
  if is_push then
    p.pos = p.pos + vec_rot(vec(.1, 0), push_dir / 4)
  end
end


return world
