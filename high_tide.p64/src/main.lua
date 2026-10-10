-- VID = 3
-- SCREEN_W = 480 / 2
-- SCREEN_H = 270 / 2

DEBUG_MODE = false

VID = 4
SCREEN_W = 480 / 3
SCREEN_H = 270 / 3

CENTER_X = SCREEN_W / 2
CENTER_Y = SCREEN_H / 2
TILE_W = 16 / 2
TILE_H = 16 / 2
TILE_FACTOR = vec(TILE_W, TILE_H)

MESSAGE_H = 12
MESSAGE_Y = SCREEN_H - MESSAGE_H
MESSAGE_TIME = 3 * 60

require "src.math"
require "src.util"
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
local PLAYER_LIGHT_MIN = 10
local PLAYER_LIGHT_STEP_MIN = 5
local PLAYER_LIGHT_STEP_MAX = 15
local PLAYER_LIGHT_AMP = 5
local PLAYER_LIGHT_FREQ = 60 * 10

local FLASHLIGHT_AMP = 5
local FLASHLIGHT_FREQ = 60 * 1

local FLASHLIGHT_MIN_R = 5
local FLASHLIGHT_MAX_R = 20
local FLASHLIGHT_START = 10
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

---@class Messages
---@field t integer
---@field strings string[]
messages = {}


--- global flags and such
FLAGS = {
  IS_HELMET = false,
  IS_FLASHLIGHT = false,
  IS_DIG_ALLOWED = false,
  TABLET_COUNT = 0,
}

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

---@param m string[]
function push_messages(m)
  for _,s in ipairs(m) do
    add(messages.strings, s)
  end

  if messages.t <= 0 then
    messages.t = MESSAGE_TIME
  end
end

function pickup_tile(pos)
  local t = world.tiles:get(pos.x, pos.y)

  if t == 28 then
    FLAGS.IS_FLASHLIGHT = true
    push_messages({"Found a flashlight!", "Press Z to toggle."})
  elseif t == 29 then
    FLAGS.IS_HELMET = true
    p.air = p.air * PLAYER_HELMET_AIR / PLAYER_BASE_AIR
    p.respawn_t = 60 -- forces to stop and regain air
    push_messages({"Found a helmet!", "Breathe for longer underwater."})
  elseif t == 30 then
    FLAGS.IS_DIG_ALLOWED = true
    push_messages({"Found a shovel!", "Push walls to dig."})
  elseif t == 31 then
    FLAGS.TABLET_COUNT = FLAGS.TABLET_COUNT + 1
    push_messages({"Found a tablet!", "1 / ???"})
  else
    log.warn("Tried to pickup invalid tile", t)
  end

  world.tiles:set(pos.x, pos.y, 0)
end

function _init()
  colors.build_color_palette()
  
  world = world_mod.new("map/shallows.map")
  p = player_mod.new(10, 9, 0)


  for x = 0, tiles:width() - 1 do
    for y = 0, tiles:height() - 1 do
      local t = tiles:get(x, y)

      if fget(t, 2) then
        add(actors, actor.bubble_spawner(vec(x + 0.5, y + 0.5)))
      end
    end
  end
  
  screen_buffer = userdata("u8", SCREEN_W, SCREEN_H)

  messages = {
    strings = {},
    t = 0,
  }
  
  vid(VID)
end

function _draw()
  local y = p.pos.y
  
  dtm.push_target(screen_buffer)

  world:draw()
  
  lighting.clear()
  lighting.light_tiles()
  -- lighting.light_rows(-y * TILE_H, TILE_H * 25)


  lighting.light_vignette()
  if p.is_flashlight then

    
    local dir_vec = dir_to_vec(p.dir)
    local light_start = vec(CENTER_X, CENTER_Y) + dir_vec * FLASHLIGHT_START
     
    local flashlight_s = 32 + p.dir
    if p.dir == 0 then
      flashlight_s = flashlight_s | 0x20000
    elseif p.dir == 1 then
      flashlight_s = flashlight_s | 0x90000
    elseif p.dir == 2 then
      flashlight_s = flashlight_s | 0x60000
    elseif p.dir == 3 then
      flashlight_s = flashlight_s | 0x10000
    end
    lighting.light_spr(flashlight_s, light_start.x, light_start.y)

  end
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

  --- messages
  if #messages.strings > 0 then
    rrectfill(0, MESSAGE_Y, SCREEN_W, MESSAGE_H, 0, 32)

    local w, h = measure_string(messages.strings[1])

    print(messages.strings[1], CENTER_X - w / 2, MESSAGE_Y + 2, COLORS.TEXT)
  end

  color(7)
  -- print(stat(1))
  -- print("AIR: "..p.air // 60)
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

  if messages.t > 0 then
    messages.t = messages.t - 1
    if messages.t <= 0 then
      deli(messages.strings, 1)
      if #messages.strings > 0 then
        messages.t = MESSAGE_TIME
      end
    end
  end
end
