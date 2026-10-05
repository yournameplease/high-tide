-- VID = 3
-- SCREEN_W = 480 / 2
-- SCREEN_H = 270 / 2

VID = 4
SCREEN_W = 480 / 3
SCREEN_H = 270 / 3

CENTER_X = SCREEN_W / 2
CENTER_Y = SCREEN_H / 2
TILE_W = 16 / 2
TILE_H = 16 / 2
TILE_FACTOR = vec(TILE_W, TILE_H)

require "src.math"
require "src.util.log"
---@alias vec2 userdata

local dtm = require "src.util.draw_target_manager"
local colors = require "src.colors"
local lighting = require "src.lighting"
local world_mod = require "src.world"
local player_mod = require "src.player"
local actor = require "src.actor"

local PLAYER_LIGHT_STEP_FACTOR = 5
-- in pixels
local PLAYER_LIGHT_STEP_MIN = 10
local PLAYER_LIGHT_STEP_MAX = 50
local PLAYER_LIGHT_AMP = 5
local PLAYER_LIGHT_FREQ = 60 * 10

local FLASHLIGHT_AMP = 5
local FLASHLIGHT_FREQ = 60 * 1

local FLASHLIGHT_MIN_R = 5
local FLASHLIGHT_MAX_R = 20
local FLASHLIGHT_START = 20
local FLASHLIGHT_END = 80
local FLASHLIGHT_STEPS = 9

CONFIG = {
  LOG_LEVEL = "DEBUG",  
}

local COLOR_TABLE_ADDRS = {
  [0] = 0x8000,
  0x9000,
  0xA000,
  0xB000,
}

local global_t = 0
local screen_buffer

-- globals (eww) for convenience
world = {}
p = {}
actors = {}
tiles = {}


function apply_color_table(color_table_sprite, idx)
  idx = idx or 0
	local sprite=get_spr(color_table_sprite)
	--copy the sprite into the address 0x8000 in memory
	memmap(sprite,COLOR_TABLE_ADDRS[idx])
	--poke the bit that makes it work for shapes(circ,rect etc.), the bit for sprites
	--is already set by default.
	poke(0x550b,0x3f)
	--the color table got copied and will be used. This is the same color table 
	--that pal() modifies.
end


function _init()
  colors.build_color_palette()
  
  world = world_mod.new("map/shallows.map")
  p = player_mod.new(10, 4, 0)


  for x = 0, tiles:width() - 1 do
    for y = 0, tiles:height() - 1 do
      local t = tiles:get(x, y)

      if fget(t, 2) then
        add(actors, actor.bubble_spawner(vec(x + 0.5, y + 0.5)))
      end
    end
  end
  
  screen_buffer = userdata("u8", SCREEN_W, SCREEN_H)

  vid(VID)
end

function _draw()
  local y = p.pos.y
  
  dtm.push_target(screen_buffer)

  world:draw()
  
  camera()
  lighting.clear()
  lighting.light_rows(-y * TILE_H, TILE_H * 25)

  local air_light_factor = 2 * mid(0.1, p.air / PLAYER_BASE_AIR, 0.5)
  local flashlight_step = max(PLAYER_LIGHT_STEP_MAX - y / PLAYER_LIGHT_STEP_FACTOR, PLAYER_LIGHT_STEP_MIN)
  local player_light_offset = PLAYER_LIGHT_AMP * math.sin(global_t / PLAYER_LIGHT_FREQ)
  local flashlight_offset = FLASHLIGHT_AMP * math.sin(global_t / FLASHLIGHT_FREQ)
  lighting.light_disks(CENTER_X, CENTER_Y,
    player_light_offset, flashlight_step * air_light_factor)

  if p.is_flashlight then
    local lightness = 0
    if p.battery < 3 * 60 then
      lightness = 1
    end

    local factor = 1
    if p.battery < 50 then
      factor = p.battery / 50
    end

    local dir_vec = dir_to_vec(p.dir)
    local light_start = vec(CENTER_X, CENTER_Y) + dir_vec * FLASHLIGHT_START
    local light_end = vec(CENTER_X, CENTER_Y) + dir_vec * FLASHLIGHT_END
    lighting.light_cone(
      light_start.x, light_start.y, (FLASHLIGHT_MIN_R) * factor,
      light_end.x, light_end.y, (FLASHLIGHT_MAX_R+flashlight_offset) * factor,
      FLASHLIGHT_STEPS,
      lightness
    )
  end
  -- lighting.light_rows(100, 30)
  lighting.draw_lighting()

  dtm.pop()

  -- "water shader"
  -- local S = 20
  -- for i = 1, S do
  --   local y = (i / S + math.sin(global_t / 500) / S) * SCREEN_H 
  --   local o = (2 + 1 * math.sin(global_t / 100))
  --   screen_buffer:blit(screen_buffer, 5, y, 5 + o, y, SCREEN_W - 10, 2)
  -- end

  cls()
  spr(screen_buffer, 0, 0)

  -- for i = 1, 9 do
  --   circfill(100 + 20 * i, 20 * i, 10, COLORS.DARK[i])
  -- end

  color(7)
  print(stat(1))
  print("AIR: "..p.air // 60)
  print("BATTERY: "..p.battery // 60)
end
 
function _update()
  global_t = global_t + 1
  world:update()

  local i = 1
  while i <= #actors do
    local a = actors[i]
    a:update()
    if a.should_die then
      -- note: O(n^2)
      deli(actors, i)
    else
      i = i+1
    end
  end
  p:update()
end
