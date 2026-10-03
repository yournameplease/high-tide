local player_mod = require "src.player"

local WATER_X_AMP = 0.0004
local WATER_Y_AMP = 0.0004
local WATER_X_FREQ = 127
local WATER_Y_FREQ = 63
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
  self.bg = m[1].bmp
  self.tiles = m[2].bmp
  self.fg = m[3].bmp

  p = player_mod.new(8, 4, 0)
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

  p:update()
end

function World:draw()
  cls(COLORS.BG)

  local p_pos = p.pos * TILE_FACTOR
  local cam_x = p_pos.x - CENTER_X
  local cam_y = p_pos.y - CENTER_Y
  camera(cam_x, cam_y)

  map(self.bg, 0, 0, 0 - p.pos.x / 10)
  map(self.tiles, 0, 0)

  p:draw()
  
  map(self.fg, 0, 0, p.pos.x / 10)

  camera()
end


return world
