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

local crab = require "crab.crab_gui.gui"
local dtm = require "src.util.draw_target_manager"
local colors = require "src.colors"
local lighting = require "src.lighting"
local world_mod = require "src.world"
local player_mod = require "src.player"
local actor = require "src.actor"
local menu = require "src.menu"
local gui

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

MENU_TRANSITION_T = 1 * 60
MENU_LERP_T = 1 * 60
MENU_Y = 0
SETTINGS_Y = 12 * 8

CONFIG = {
  LOG_LEVEL = "DEBUG",  
}

SAVE_DATA = {
  PEACEFUL_MODE = false,  
  SPEEDRUN_TIMER = false,  
}

local COLOR_TABLE_ADDRS = {
  [0] = 0x8000,
  0x9000,
  0xA000,
  0xB000,
}

local screen_buffer

-- globals (eww) for convenience
world = {}
p = {}
actors = {}
tiles = {}
transition_t = nil
finish_t = 100 * 60 * 60

---@class Messages
---@field t integer
---@field strings string[]
messages = {}


--- global flags and such
FLAGS = {}

THEME = {
  UI_PAD = 2,
  ROW_H = 10,
  PANEL_PAD = 10,
  UI_BORDER_PAD = 0,
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
      sfx(6)
    FLAGS.IS_FLASHLIGHT = true
    push_messages({"Found a flashlight!", chr(142) .. " to toggle."})
  elseif t == 29 then
      sfx(6)
    FLAGS.IS_HELMET = true
    p.air = p.air * PLAYER_HELMET_AIR / PLAYER_BASE_AIR
    p.respawn_t = 60 -- forces to stop and regain air
    push_messages({"Found a helmet!", "Breathe for longer underwater."})
  elseif t == 30 then
      sfx(6)
    FLAGS.IS_DIG_ALLOWED = true
    push_messages({"Found a shovel!", "Push walls to dig."})
  elseif t == 31 then
    FLAGS.TABLET_COUNT = FLAGS.TABLET_COUNT + 1
    if FLAGS.TABLET_COUNT == 4 then
      world:open_door()
      sfx(3)
      push_messages({"Found a tablet!", "Something shifted."})
    else
      sfx(4)
      push_messages({"Found a tablet!", FLAGS.TABLET_COUNT .. " / 4"})
    end
  else
    log.warn("Tried to pickup invalid tile", t)
  end

  world.tiles:set(pos.x, pos.y, 0)
end

function _init()
  colors.build_color_palette()
  vid(VID)
  screen_buffer = userdata("u8", SCREEN_W, SCREEN_H)

  gui = crab.new()

  enter_menu()
end

function game_init()
  global_t = 0
  world = world_mod.new("map/shallows.map")
  p = player_mod.new(14, 9, 0)
  p.air = 0
  p:respawn()

  for x = 0, tiles:width() - 1 do
    for y = 0, tiles:height() - 1 do
      local t = tiles:get(x, y)

      if fget(t, 2) then
        add(actors, actor.bubble_spawner(vec(x + 0.5, y + 0.5)))
      end
    end
  end
  
  messages = {
    strings = {},
    t = 0,
  }
 
end

function game_draw()
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
    if p.battery < BATTERY_WEAK_DURATION then
      flashlight_s = flashlight_s - 8
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

  color(COLORS.TEXT)
  -- print(stat(1))
  -- print("AIR: "..p.air // 60)
  -- print("BATTERY: "..p.battery // 60)
  print(to_time_string(global_t), 1, 1)
end
 
function game_update()
  if transition_t then 
    transition_t = transition_t - 1
    if transition_t <= 0 then
      enter_credits()
      transition_t = nil
      return
    end 
  end
  
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

function enter_game()
  FLAGS = {
    IS_HELMET = false,
    IS_FLASHLIGHT = false,
    IS_DIG_ALLOWED = false,
    TABLET_COUNT = 0,
  }

  game_init()
  _update = game_update
  _draw = game_draw
end

function enter_credits()
  credits_init()
  _update = credits_update
  _draw = credits_draw
end

function enter_menu()
  menu_init()
  _update = menu_update
  _draw = menu_draw
end

function return_to_menu()
  menu_init()
  _update = menu_update
  _draw = menu_draw
  lerp_t = MENU_LERP_T
end

function enter_settings()
  settings_init()
  _update = settings_update
  _draw = settings_draw
end

function menu_init()
  menu_t = 0
  lerp_t = 0
  main_menu = menu.new_list(
    "vertical",
    {
      menu.button("Play", enter_game),
      menu.button("Settings", enter_settings),
    }
  )

  main_menu_map = fetch("map/main_menu.map")[1].bmp
end

function menu_update()
  if lerp_t > 0 then
    lerp_t = lerp_t - 1
  end
  menu_t = menu_t + 1
  main_menu:update()
end

function menu_draw()
  local y = lerp(lerp_t / MENU_LERP_T, MENU_Y, SETTINGS_Y)
  local map_offset = 2*cos(menu_t / 1200)
  
  gui:flush()
  main_menu:layout(gui)
  gui:event_step()
  cls(COLORS.BG)

  map(main_menu_map, 0, 0, 0, map_offset - y, 20, 5)
  map(main_menu_map, 0, 5, 0, 8 * 5 - y)

  if lerp_t <= 0 then
    local w = measure_string("HIGH TIDE")
    print("HIGH TIDE", CENTER_X - w / 2, 8)
    -- print("TIDE", CENTER_X - 20 , 30)
    gui:draw()
  end
end

function settings_init()
  lerp_t = MENU_LERP_T
  main_menu = menu.new_list(
    "vertical",
    {
      menu.toggle("Peaceful Mode",  SAVE_DATA.PEACEFUL_MODE),
      menu.toggle("Speedrun Timer", SAVE_DATA.SPEEDRUN_TIMER),
      menu.button("Back", return_to_menu),
    }
  )
end

function settings_update()
  if lerp_t > 0 then
    lerp_t = lerp_t - 1
  end
  
  menu_t = menu_t + 1
  settings_change = main_menu:update()

  if settings_change then
    SAVE_DATA.PEACEFUL_MODE = main_menu:get_value"Peaceful Mode" or SAVE_DATA.PEACEFUL_MODE
    SAVE_DATA.SPEEDRUN_TIMER = main_menu:get_value"Speedrun Timer" or SAVE_DATA.SPEEDRUN_TIMER
    log.debug("save data", SAVE_DATA.PEACEFUL_MODE, SAVE_DATA.SPEEDRUN_TIMER)
    store("/appdata/high_tide.pod", SAVE_DATA)
  end
end

function settings_draw()
  local map_offset = 2*cos(menu_t / 1200)

  gui:flush()
  main_menu:layout(gui)
  gui:event_step()
  cls(COLORS.BG)

  local y = lerp(lerp_t / MENU_LERP_T, SETTINGS_Y, MENU_Y)
  map(main_menu_map, 0, 0, 0, map_offset - y, 20, 5)
  map(main_menu_map, 0, 5, 0, 8 * 5 - y)
  if lerp_t <= 0 then
    local w = measure_string("SETTINGS")
    print("SETTINGS", CENTER_X - w / 2, 24)
    gui:draw()
  end
end



function credits_init()
  global_t = 0
  credits_map = fetch("map/credits.map")[1].bmp
end

function credits_update()
  global_t = global_t + 1
  if transition_t then 
    transition_t = transition_t - 1
    if transition_t <= 0 then
      enter_menu()
      transition_t = nil
    end 
  end
  
  if btnp(4) then
    if transition_t == nil then
      transition_t = MENU_TRANSITION_T
    end
  end
end

function credits_draw()

  cls(COLORS.BG)
  map(credits_map)

  rrectfill(0, 0, SCREEN_W, SCREEN_H, 0, COLORS.DARK[7])
  
  color(COLORS.TEXT)
  -- if global_t < 600 then
    local s1 = "A sandfolk returns to Atlantis."
    local w1 = measure_string(s1)
    print(s1, CENTER_X - w1 / 2, 10)
  -- else
    local s2 = "A game by yournameplease."
    local w2 = measure_string(s2)
    print(s2, CENTER_X - w2 / 2, 30)
  -- end
  local s3 = "Completion time: " .. to_time_string(finish_t)
  local w3 = measure_string(s3)
  print(s3, CENTER_X - w3 / 2, 50)

  local s4 = "Return to menu: " .. chr(142)
  local w4 = measure_string(s4)
  print(s4, CENTER_X - w4 / 2, 80)
end

