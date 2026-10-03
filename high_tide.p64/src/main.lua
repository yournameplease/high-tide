SCREEN_W = 480
SCREEN_H = 270
CENTER_X = SCREEN_W / 2
CENTER_Y = SCREEN_H / 2
TILE_W = 16
TILE_H = 16
TILE_FACTOR = vec(TILE_W, TILE_H)

require "src.math"
require "src.util.log"
---@alias vec2 userdata

local dtm = require "src.util.draw_target_manager"
local colors = require "src.colors"
local lighting = require "src.lighting"
local world_mod = require "src.world"

local FLASHLIGHT_STEP_FACTOR = 5
-- in pixels
local FLASHLIGHT_STEP_MIN = 10
local FLASHLIGHT_STEP_MAX = 50
local FLASHLIGHT_AMP = 10
local FLASHLIGHT_FREQ = 60 * 10

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
local game = {}

-- globals (eww) for convenience
world = {}
p = {}
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
  
  game.world = world_mod.new("map/0.map")

  screen_buffer = userdata("u8", SCREEN_W, SCREEN_H)
end

function _draw()
  local y = p.pos.y
  
  dtm.push_target(screen_buffer)

  game.world:draw()
  
  camera()
  local depth = math.log(y + 10) / 20

  lighting.clear()
  lighting.light_rows(-y * TILE_H, TILE_H * 25)


  local flashlight_step = max(FLASHLIGHT_STEP_MAX - y / FLASHLIGHT_STEP_FACTOR, FLASHLIGHT_STEP_MIN)
  local flashlight_offset = FLASHLIGHT_AMP * math.sin(global_t / FLASHLIGHT_FREQ)
  lighting.light_disks(CENTER_X, CENTER_Y, 20 + flashlight_offset, flashlight_step)
  -- lighting.light_rows(100, 30)
  lighting.draw_lighting()

  dtm.pop()

  -- "water shader"
  local S = 20
  for i = 1, S do
    local y = (i / S + math.sin(global_t / 500) / S) * SCREEN_H 
    local o = (2 + 1 * math.sin(global_t / 100))
    screen_buffer:blit(screen_buffer, 5, y, 5 + o, y, SCREEN_W - 10, 2)
  end

  cls()
  spr(screen_buffer, 0, 0)

  -- for i = 1, 9 do
  --   circfill(100 + 20 * i, 20 * i, 10, COLORS.DARK[i])
  -- end

  color(7)
  print(stat(1))
end
 
function _update()
  global_t = global_t + 1
  game.world:update()
end
