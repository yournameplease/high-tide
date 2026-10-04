local PLAYER_HALF_H = 0.7
local PLAYER_HALF_W = 0.2
local PLAYER_FRIC = 0.95
-- local PLAYER_STROKE_VEL = 0.2
-- local PLAYER_STROKE_TIME = 25
local PLAYER_STROKE_VEL = 0.4
local PLAYER_SHORT_STROKE_VEL = 0.13
local PLAYER_STROKE_TIME = 45
local PLAYER_SHORT_STROKE_TIME = 15

PLAYER_BASE_AIR = 30 * 60

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
---@field air integer ticks of air
---@field in_air boolean
---@field stroke_held boolean false if ever not pressing a direction, reset to true on stroke
local Player = {}
Player.__index = Player

local player = {}

function player.new(x, y, dir)
  local self = setmetatable({
    pos = vec(x, y),
    vel = vec(0, 0),
    t = 0,
    stroke_t = 0,
    dir = dir,
    air = PLAYER_BASE_AIR,
    held_stroke = false,
  }, Player)

  return self
end

function Player:update()
    local any_move = false

    local dx = 0
    local dy = 0

    if (btn(0))then any_move = true dx = dx - 1 end
    if (btn(1))then any_move = true dx = dx + 1 end
    if (btn(2))then any_move = true dy = dy - 1 end
    if (btn(3))then any_move = true dy = dy + 1 end

    if not any_move then
      self.stroke_held = false
    end

    if self.stroke_t <= 0 then

      local new_dir
      if abs(dy) > abs(dx) then
        if dy >= 0 then new_dir = 3 else new_dir = 1 end
      elseif abs(dx) > 0 then
        if dx >= 0 then new_dir = 0 else new_dir = 2 end
      end

      if new_dir then
        -- don't turn around hard
        if abs(self.dir - new_dir) == 2 then
          new_dir = self.dir
        end

        self.dir = new_dir
      end

      if any_move then

        local stroke_vel
        if self.stroke_held then
          stroke_vel = PLAYER_SHORT_STROKE_VEL
          self.stroke_t = PLAYER_SHORT_STROKE_TIME
        else
          stroke_vel = PLAYER_STROKE_VEL
          self.stroke_t = PLAYER_STROKE_TIME
        end
        
        self.stroke_held = true
        self.vel = self.vel + stroke_vel * normalize(vec(dx, dy))
      end
    else
      self.stroke_t = self.stroke_t - 1
    end

    self:move(p, self.vel.x, self.vel.y)
    if norm_squared(self.vel) > 0.0001 then
       self.t =  self.t + 1
    else
       self.t =  self.t // 2
    end

    -- self.vel = self.vel + world.water_vel
    self.vel = self.vel * PLAYER_FRIC
  

    if self.in_air then
      self.air = PLAYER_BASE_AIR
    else
      self.air = self.air - 1
    end
end

function Player:test_collision(pos, dir, check_feet)

  local is_solid = false
  local is_push = false
  local all_air = true
  local push_dir
  local is_breathing = false
  for i, o in ipairs(PLAYER_BODY_POINTS) do
    local step = vec_rot(o, dir/4)
    local tile_pos = pos + step
    local tile = tiles:get(tile_pos.x, tile_pos.y)

    if fget(tile, 0) then
      is_solid = true
    end
    if not fget(tile, 1) and not fget(tile, 0) then
      all_air = false
    end
  end
  for i, o in ipairs(PLAYER_FEET_POINTS) do
    local step = vec_rot(o, dir/4)
    local tile_pos = pos + step
    local tile = tiles:get(tile_pos.x, tile_pos.y)

    if fget(tile, 0) then
      if check_feet then
        is_solid = true
      end
    end
    if not fget(tile, 1) and not fget(tile, 0) then
      all_air = false
    end
  end
  for i, o in ipairs(PLAYER_HEAD_POINTS) do
    local step = vec_rot(o, dir/4)
    local tile_pos = pos + step
    local tile = tiles:get(tile_pos.x, tile_pos.y)
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
    if not fget(tile, 1) and not fget(tile, 0) then
      all_air = false
    end
  end

  -- side effect!!!
  self.in_air = is_breathing
  return is_solid or all_air
end

function Player:try_move(d_pos, check_feet)
  local new_pos = self.pos + d_pos
  
  if not self:test_collision(new_pos, self.dir, check_feet) then
    self.pos = new_pos
  end
end


function Player:move()
  if self.vel.x ~= 0 or self.vel.y ~= 0 then
    local dx = self.vel.x
    local dy = self.vel.y
    
    local check_feet = false -- makes turning against walls nicer

    local dir_vec = dir_to_vec(self.dir)
    -- don't turn around hard
    if dot(self.vel, dir_vec) < 0 then
      dx = dx * 0.5
      dy = dy * 0.5
      check_feet = true
    end

    self:try_move(vec(dx, 0), check_feet)
    self:try_move(vec(0, dy), check_feet)
  end

  local push_dir
  local is_push = false
  for i, o in ipairs(PLAYER_HEAD_POINTS) do
    local step = vec_rot(o, self.dir/4)
    local tile_pos = self.pos + step
    local tile = tiles:get(tile_pos.x, tile_pos.y)
    if fget(tile, 0) then
      if i == 1 or i == 3 then
        is_push = true
        if i == 1 then
          push_dir = (self.dir - 1) % 4
        elseif i == 3 then
          push_dir = (self.dir + 1) % 4
        end
      end
    end
  end
  if is_push then
    self.pos = self.pos + vec_rot(vec(.1, 0), push_dir / 4)
  end
end


function Player:draw()

  local hflip = false
  local vflip = false
  local index = 16 + (self.t //20 ) % 4
  if self.dir == 1 or self.dir == 3 then index = index + 4 end
  if self.dir == 2 then hflip = true end
  if self.dir == 3 then vflip = true end
  local world_pos = self.pos * TILE_FACTOR
  spr(0x30000 | index, world_pos.x,  world_pos.y + ( self.t//20%2),  hflip, vflip)

  do -- debug points
    for i, o in ipairs(PLAYER_ALL_POINTS) do
      local step = vec_rot(o, self.dir/4)
      local tile_pos = world_pos + step * TILE_FACTOR
      pset(tile_pos.x, tile_pos.y, 8)
    end
  end
end

return player
