local actor = require "src.actor"

local WATER_X_AMP = 0.0002
local WATER_Y_AMP = 0.0006
local WATER_X_FREQ = 10 * 60
local WATER_Y_FREQ = 2 * 60
local WATER_X_PHASE = 150
local SHAKE_T = 1 * 60

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
  -- self.bg = m[1].bmp
  -- self.tiles = m[2].bmp
  -- self.fg = m[3].bmp
  self.tiles = m[1].bmp

  lighting_tiles = m[2].bmp

  tiles = self.tiles

  self.t = 0
  self.shake_t = 0

  return self
end

function World:update()
  self.t = self.t + 1
  if self.shake_t > 0 then
    self.shake_t = self.shake_t - 1 
  end
  self.water_vel = vec(
    WATER_X_AMP * sin(self.t / WATER_X_FREQ + WATER_X_PHASE),
    WATER_Y_AMP * sin(self.t / WATER_Y_FREQ)
  )
end

function World:draw()
  local p_pos = p.pos * TILE_FACTOR
  local cam_x = p_pos.x - CENTER_X
  local cam_y = p_pos.y - CENTER_Y

  if self.shake_t > 0 then
    cam_x = cam_x + rnd(2) - 1
    cam_y = cam_y + rnd(2) - 1
  end

  camera(0, cam_y)

  if cam_y < SCREEN_H then
    cls()
    rrectfill(0, -SCREEN_H, SCREEN_W, SCREEN_H, 0, COLORS.BG_AIR)
    rrectfill(0, 0, SCREEN_W, 2*SCREEN_H, 0, COLORS.BG)
  else
    cls(COLORS.BG)
  end

  camera(cam_x, cam_y)

  if self.bg then
    map(self.bg, 0, 0, 0 - p.pos.x / 10)
  end
  map(self.tiles, 0, 0)

  for _,a in ipairs(actors) do
    a:draw()
  end
  
  p:draw()
  
  if self.fg then
    map(self.fg, 0, 0, p.pos.x / 10)
  end

  camera()
end

local CARDINAL_OFFSETS = {
  vec(0, 1),
  vec(0, -1),
  vec(1, 0),
  vec(-1, 0),
}

function World:break_tile(pos)
  local t = self.tiles:get(pos.x, pos.y)
  self.tiles:set(pos.x, pos.y, 0)

  actor.shotgun_particles(
    pos + vec(0.5, 0.5),
    vec(0, 0),
    ACTOR_FRIC,
    PARTICLE_LIFESPAN,
    10,
    0.05,
    COLORS.TERRAIN
  )

  for _,o in ipairs(CARDINAL_OFFSETS) do
    if self.tiles:get(pos.x + o.x, pos.y + o.y) == t then
      self:break_tile(pos + o)
    end
  end
end

function World:open_door()
  for x = 0, tiles:width() do
  for y = 0, tiles:height() do
    local t = self.tiles:get(x, y)
    if t >= 144 then
      self.tiles:set(x, y, t + 4)
      add(actors,
      actor.door(
        vec(x, y) + vec(0.5, 0.5)
      ))
    end
  end
  end

  self.shake_t = SHAKE_T
end

return world
