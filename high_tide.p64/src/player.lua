local actor = require "src.actor"

local PLAYER_PUSH_H = 0.8
local PLAYER_HALF_H = 0.6
local PLAYER_HALF_W = 0.3
local PLAYER_FRIC = 0.95

local PUSH_T = 90

local BREATH_PARTICLE_SPEED = 0.02
local PLAYER_SCALE = 1
-- local PLAYER_STROKE_VEL = 0.2
-- local PLAYER_STROKE_TIME = 25

-- TODO: consider bringing the super big strokes.  maybe slightly stronger than these but from an upgrade?
-- local PLAYER_STROKE_VEL = 0.5
-- local PLAYER_STROKE_TIME = 45
local PLAYER_SHORT_STROKE_VEL = 0.02
local PLAYER_SHORT_STROKE_TIME = 3

-- local PLAYER_STROKE_VEL = PLAYER_SHORT_STROKE_VEL
-- local PLAYER_STROKE_TIME = PLAYER_SHORT_STROKE_TIME
-- feels like slightly faster than held, which is intended.
-- does this inspire too annoying button mashing?
local PLAYER_STROKE_VEL = 0.35
local PLAYER_STROKE_TIME = 20

PLAYER_BASE_AIR = 30 * 60
PLAYER_AIR_BUBBLE_RESTORE = 10 * 60
PLAYER_AIR_BUBBLE_TIME = 1 * 60
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
---@field in_air_tile boolean
---@field in_air_bubble boolean
---@field air_bubble_t integer
---@field is_flashlight boolean
---@field hover_tile vec2
---@field push_t integer
---@field heading_forward boolean true for forward, false for backward.  used for turning
---@field stroke_held boolean false if ever not pressing a direction, reset to true on stroke
local Player = {}
Player.__index = Player

local player = {}

function player.new(x, y, dir)
  local self = setmetatable({
    pos = vec(x, y),
    vel = vec(0, 0),
    hover_tile = vec(0, 0),
    t = 0,
    stroke_t = 0,
    dir = dir,
    air = PLAYER_BASE_AIR,
    is_flashlight = false,
    battery = PLAYER_BASE_BATTERY,
    held_stroke = false,
    heading_forward = true,
    air_bubble_t = 0,
  }, Player)

  return self
end

function Player:update()
    local any_move = false

    local dx = 0
    local dy = 0
    local target_dir

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

    local target_angle
    if dx ~= 0 or dy ~= 0 then
      target_angle = atan2(dx, dy) % 1
      target_dir = flr(4 * (target_angle + 1/8))
    end

    if self.stroke_t <= 0 then

      if dx ~= 0 or dy ~= 0 then
        local new_dir
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

          if not self.heading_forward and not self:can_spin() then
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

    self:move()
    self.t =  self.t + 1

    self.vel = self.vel + world.water_vel
    self.vel = self.vel * PLAYER_FRIC
  
    do
      local step = vec_rot(vec(PLAYER_PUSH_H, 0), self.dir/4)
      local tile_pos = self.pos + step
      tile_pos.x = flr(tile_pos.x)
      tile_pos.y = flr(tile_pos.y)

      if self.hover_tile.x ~= tile_pos.x or self.hover_tile.y ~= tile_pos.y then
        self.push_t = PUSH_T
        self.hover_tile = tile_pos
      end

      local tile = tiles:get(tile_pos.x, tile_pos.y)
      if target_dir and self.dir == target_dir then 
        if (fget(tile, 4) and self.dir == 0)
          or (fget(tile, 5) and self.dir == 1)
          or (fget(tile, 6) and self.dir == 2) then
          self.push_t = self.push_t - 1
        end
      else 
        self.push_t = PUSH_T
      end

      if self.push_t == 0 then
        world:break_tile(self.hover_tile)
        self.push_t = PUSH_T
      end
    end


    do -- air bubbles
      local step = vec_rot(PLAYER_HEAD_POINTS[2], self.dir/4)
      local head_pos = self.pos + step
      for _, a in ipairs(actors) do
        if a.type == "bubble" and a.t > 4 * 60 and
        norm_squared(head_pos - a.pos) < 0.4 then

          self.in_air_bubble = true
          a.should_die = true
          for i = 1, 4 do
            
            -- TODO I'd rather these be emitted on a delay in sequence
            local p = actor.new_particle(
              head_pos,
              vec(rnd(0.1)-0.05, -i * BREATH_PARTICLE_SPEED),
              ACTOR_FRIC,
              PARTICLE_LIFESPAN
            )
            add(actors, p)
          end

          break
        end 
      end
    end

    if self.air_bubble_t > 0 then
      self.air_bubble_t = self.air_bubble_t - 1
      self.air = self.air + PLAYER_BASE_AIR * 0.01
    elseif self.in_air_tile then
      self.air = self.air + PLAYER_BASE_AIR * 0.01
      -- consider restricting this to "sun" tiles?
      self.battery = PLAYER_BASE_BATTERY
    elseif self.in_air_bubble and not self.is_air_bubbling then
      self.in_air_bubble = false
      self.air_bubble_t = PLAYER_AIR_BUBBLE_TIME
    else
      self.air = self.air - 1
    end
    self.air = min(self.air, PLAYER_BASE_AIR)
end

function Player:is_collision(pos, dir)

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
  self.in_air_tile = is_breathing
  return is_solid or all_air
end

function Player:try_move(d_pos)
  local new_pos = self.pos + d_pos
  
  if not self:is_collision(new_pos, self.dir) then
    self.pos = new_pos
  end
end

---@return boolean success
function Player:try_turn(new_dir)
  if not self:is_collision(self.pos, new_dir) then
    self.dir = new_dir

    return true
  end
  return false
end

function Player:can_spin()
  for i = 0, 3 do
    if self:is_collision(self.pos, i) then
      return false
    end
  end
  return true
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
  local index = 40

  if norm_squared(self.vel) > 0.04 then
    index = index + 1
  else
    if self.stroke_held  then
      index = index + 2 + (self.t // 16) % 2
    end
  end

  if self.dir == 1 or self.dir == 3 then index = index + 4 end
  if self.dir == 2 then hflip = true end
  if self.dir == 3 then vflip = true end
  local world_pos = self.pos * TILE_FACTOR
  spr(0x30000 | index, world_pos.x,  world_pos.y,  hflip, vflip)
  -- sspr(0x30000 | index, 0, 0, 16, 16, world_pos.x,  world_pos.y, 16 * PLAYER_SCALE, 16 * PLAYER_SCALE,  hflip, vflip)

  do -- debug points
    -- for i, o in ipairs(PLAYER_ALL_POINTS) do
    --   local step = vec_rot(o, self.dir/4)
    --   local tile_pos = world_pos + step * TILE_FACTOR
    --   pset(tile_pos.x, tile_pos.y, 8)
    -- end
    --
    pset((self.hover_tile.x + 0.5) * TILE_FACTOR.x, (self.hover_tile.y + 0.5) * TILE_FACTOR.y, 8)
  end
end

return player
