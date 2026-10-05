local ACTOR_FRIC = 0.95


local BUBBLE_ACCEL_TIME = 3 * 60
local BUBBLE_ACCEL = 0.0005
local BUBBLE_LIFESPAN = 20 * 60
local BUBBLE_POP_SPEED = 0.04

PARTICLE_LIFESPAN = 1 * 60

---@class Actor
---@field type string
---@field pos vec2
---@field vel vec2
---@field sprite_index integer
---@field t integer
---@field lifespan integer
---@field is_solid boolean
local Actor = {}
Actor.__index = Actor

---@class Spawner
---@field type string
---@field pos vec2
---@field t integer
---@field spawn_time integer
local Spawner = {}
Spawner.__index = Spawner


local actor = {}

function actor.new_bubble(pos)
  local self = setmetatable({
    type = "bubble",
    pos = pos,
    vel = vec(0, 0),
    fric = ACTOR_FRIC,
    t = 0,
    lifespan = BUBBLE_LIFESPAN,
    sprite_index = 56,
    is_solid = false,
  }, Actor)

  return self
end

-- just a full actor for particles... for now...
function actor.new_particle(pos, vel, fric, lifespan)
  local self = setmetatable({
    type = "particle",
    pos = pos,
    vel = vel,
    fric = fric,
    t = 0,
    lifespan = lifespan,
    is_solid = false,
  }, Actor)

  return self
end

function Actor:try_move(d_pos)
  local new_pos = self.pos + d_pos
  
  -- TODO: is_solid
  -- if not self:is_collision(new_pos, self.dir) then
    self.pos = new_pos
  -- end
end


function Actor:move()
  if self.vel.x ~= 0 or self.vel.y ~= 0 then
    local dx = self.vel.x
    local dy = self.vel.y
    
    self:try_move(vec(dx, 0))
    self:try_move(vec(0, dy))
  end
end

function Actor:update()
    if self.type == "bubble" then
      if self.t < BUBBLE_ACCEL_TIME then 
        self.vel = self.vel - vec(0, BUBBLE_ACCEL)
      end
    end

    self:move()
    self.t =  self.t + 1

    self.vel = self.vel + world.water_vel
    self.vel = self.vel * ACTOR_FRIC

    if self.t > self.lifespan then
      self.should_die = true

      
      if self.type == "bubble" then
        for i = 0, 9 do
        
          local p = actor.new_particle(
            self.pos + 0.3 * vec_from_angle(i/10),
            BUBBLE_POP_SPEED * vec_from_angle(i /10),
            ACTOR_FRIC,
            PARTICLE_LIFESPAN
          )
          add(actors, p)
        end
      end
    end
    
end

function Actor:draw()
  local world_pos = self.pos * TILE_FACTOR

  if self.type == "particle" then
    pset(world_pos.x, world_pos.y, COLORS.PARTICLE)      
    return
  end
  
  local index = self.sprite_index
  if self.type == "bubble" then
    index = index + min(self.t // (1 * 60), 3)
  end
  local hflip = false
  local vflip = false

  spr(0x30000 | index, world_pos.x,  world_pos.y,  hflip, vflip)
end


function actor.bubble_spawner(pos)
  local self = setmetatable({
    type = "bubble",
    pos = pos,
    t = 0,
    spawn_time = BUBBLE_LIFESPAN,
  }, Spawner)

  return self
end

function Spawner:update()
    self.t =  self.t - 1

    if self.t <= 0 then
      add(actors, actor.new_bubble(self.pos))
      self.t = self.spawn_time
    end
end


function Spawner:draw()
  --noop
end

return actor
