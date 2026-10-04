local PLAYER_HALF_H = 0.6
local PLAYER_HALF_W = 0.3
local PLAYER_FRIC = 0.95
-- local PLAYER_STROKE_VEL = 0.2
-- local PLAYER_STROKE_TIME = 25

-- TODO: consider bringing the super big strokes.  maybe slightly stronger than these but from an upgrade?
-- local PLAYER_STROKE_VEL = 0.5
-- local PLAYER_STROKE_TIME = 45
local PLAYER_SHORT_STROKE_VEL = 0.05
local PLAYER_SHORT_STROKE_TIME = 5

-- local PLAYER_STROKE_VEL = PLAYER_SHORT_STROKE_VEL
-- local PLAYER_STROKE_TIME = PLAYER_SHORT_STROKE_TIME
-- feels like slightly faster than held, which is intended.
-- does this inspire too annoying button mashing?
local PLAYER_STROKE_VEL = 0.3
local PLAYER_STROKE_TIME = 20

PLAYER_BASE_AIR = 30 * 60
PLAYER_BASE_BATTERY = 15 * 60
BATTERY_WEAK_DURATION = 2 * 60

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
---@field is_flashlight boolean
---@field heading_forward boolean true for forward, false for backward.  used for turning
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
    is_flashlight = false,
    battery = PLAYER_BASE_BATTERY,
    held_stroke = false,
    heading_forward = true,
  }, Player)

  return self
end

function Player:update()
    local any_move = false

    local dx = 0
    local dy = 0

    if btnp(4) or btnp(5) then
      self.is_flashlight = not self.is_flashlight

      if self.battery < 0 then self.battery = BATTERY_WEAK_DURATION end
    end

    if self.is_flashlight then
      self.battery = self.battery - 1
      if self.battery < 0 then self.is_flashlight = false end
    end
    
    if (btn(0))then any_move = true dx = dx - 1 end
    if (btn(1))then any_move = true dx = dx + 1 end
    if (btn(2))then any_move = true dy = dy - 1 end
    if (btn(3))then any_move = true dy = dy + 1 end

    if not any_move then
      self.stroke_held = false
    end

    if self.stroke_t <= 0 then

      if dx ~= 0 or dy ~= 0 then
        local new_dir
        local target_angle = atan2(dx, dy) % 1
        target_angle = flr(8 * (target_angle + 1/16)) / 8

        local diff = target_angle - self.dir / 4
        local diff_min = min(abs(diff), abs(1 - abs(diff)))

        -- no turns when stick is 45 degrees from current
        if diff_min > 0.125 and diff_min < 0.5 then
          local dir_step
          if diff > 0 and diff < 0.5 or diff < -0.5 then
            dir_step = 1
          else
            dir_step = -1
          end

          if not self.heading_forward then
            dir_step = -dir_step
          end

          new_dir = (self.dir + dir_step) % 4
        end

        local did_turn
        if new_dir then
          did_turn = self:try_turn(new_dir)
        end

        local new_diff = target_angle - self.dir / 4
        local new_diff_min = min(abs(new_diff), abs(1 - abs(new_diff)))
        if new_diff_min < 0.25 or did_turn then
          self.heading_forward = true
        elseif new_diff_min > 0.25 then
          self.heading_forward = false
        end

        log.debug(self.dir, target_angle, self.heading_forward)
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
      -- consider restricting this to "sun" tiles?
      self.battery = PLAYER_BASE_BATTERY
    else
      self.air = self.air - 1
    end
end

function Player:test_collision(pos, dir)

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
      is_solid = true
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

function Player:try_move(d_pos)
  local new_pos = self.pos + d_pos
  
  if not self:test_collision(new_pos, self.dir) then
    self.pos = new_pos
  end
end

---@return boolean success
function Player:try_turn(new_dir)
  if not self:test_collision(self.pos, new_dir) then
    self.dir = new_dir

    return true
  end
  return false
end


function Player:move()
  if self.vel.x ~= 0 or self.vel.y ~= 0 then
    local dx = self.vel.x
    local dy = self.vel.y
    

    local dir_vec = dir_to_vec(self.dir)
    -- don't turn around hard
    if dot(self.vel, dir_vec) < 0 then
      dx = dx * 0.5
      dy = dy * 0.5
    end

    self:try_move(vec(dx, 0))
    self:try_move(vec(0, dy))
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
  spr(0x30000 | index, world_pos.x,  world_pos.y,  hflip, vflip)

  do -- debug points
    -- for i, o in ipairs(PLAYER_ALL_POINTS) do
    --   local step = vec_rot(o, self.dir/4)
    --   local tile_pos = world_pos + step * TILE_FACTOR
    --   pset(tile_pos.x, tile_pos.y, 8)
    -- end
  end
end

return player
