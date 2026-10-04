
local WATER_X_AMP = 0.0002
local WATER_Y_AMP = 0.0006
local WATER_X_FREQ = 10 * 60
local WATER_Y_FREQ = 2 * 60
local WATER_X_PHASE = 150

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

  tiles = self.tiles

  self.t = 0

  return self
end

function World:update()
  self.t = self.t + 1
  self.water_vel = vec(
    WATER_X_AMP * sin(self.t / WATER_X_FREQ + WATER_X_PHASE),
    WATER_Y_AMP * sin(self.t / WATER_Y_FREQ)
  )
end

function World:draw()
  local p_pos = p.pos * TILE_FACTOR
  local cam_x = p_pos.x - CENTER_X
  local cam_y = p_pos.y - CENTER_Y

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

  p:draw()
  
  if self.fg then
    map(self.fg, 0, 0, p.pos.x / 10)
  end

  camera()
end


return world
