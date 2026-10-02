local dtm = require "src.util.draw_target_manager"

-- local SCREEN_W = 480
-- local SCREEN_H = 270
local SCREEN_W = 480 / 1
local SCREEN_H = 270 / 1
local C_X = SCREEN_W / 2
local C_Y = SCREEN_H / 2

local COLOR_TABLE_ADDRS = {
  [0] = 0x8000,
  0x9000,
  0xA000,
  0xB000,
}


local global_t = 0
local screen_buffer

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
  x = 232
  y = 10
  t = 0

  local m = fetch(DATP.."map/0.map")
  bg = m[1].bmp
  tiles = m[2].bmp
  fg = m[3].bmp

  apply_color_table(8)
  palt(0, true)
  -- vid(3)
  --
  screen_buffer = userdata("u8", SCREEN_W, SCREEN_H)
end

function _draw()
  dtm.push_target(screen_buffer)

  
  cls(1)   
  -- rrectfill(x+2,y+15,12,4,1,19) -- draw a 12x4 px shadow with colour 19 (dark green)
  local index = 17 + (t //20 ) % 4

  local cam_x = x - C_X
  local cam_y = y - C_Y
  camera(cam_x, cam_y)
  
  map(bg, 0, 0, 0 - x / 10)
  map(tiles, 0, 0)

  local w = 32 * 2
  local h = 16 * 2
  sspr(0x30000 | index, 0, 0, 32, 16, x, y + (t//20%2), w, h, hflip) -- draw bunny; (x/8%2) is for hopping motion

  map(fg, 0, 0, x / 10)


  camera()
  local depth = math.log(y + 10) / 20
  for i = 1, 6 do 
    fillp(0xA5A5)
    circfill(C_X, C_Y, 20 + 10 * i / depth, 0x800000000 | 36)
    fillp()
    circfill(C_X, C_Y, 30 + 10 * i / depth, 0x800000000 | 36)
  end

  dtm.pop()

  local S = 20
  for i = 1, S do
    local y = (i / S + math.sin(global_t / 500) / S) * SCREEN_H 
    local o = (2 + 1 * math.sin(global_t / 100))
    -- local o = 2
    screen_buffer:blit(screen_buffer, 5, y, 5 + o, y, SCREEN_W - 10, 2)
  end

  cls()
  spr(screen_buffer, 0, 0)
end
 
function _update()
  global_t = global_t + 1
  local any_move = false
  if (btn(0))then any_move = true x = x - 2 hflip = true end
  if (btn(1))then any_move = true x = x + 2 hflip = false end
  if (btn(2))then any_move = true y = y - 2 end
  if (btn(3))then any_move = true y = y + 2 end

  if any_move then t = t + 1
  else t = t // 2 end
end
