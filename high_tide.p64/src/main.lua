-- local SCREEN_W = 480
-- local SCREEN_H = 270
local SCREEN_W = 480 / 2
local SCREEN_H = 270 / 2
local C_X = SCREEN_W / 2
local C_Y = SCREEN_H / 2

local COLOR_TABLE_ADDRS = {
  [0] = 0x8000,
  0x9000,
  0xA000,
  0xB000,
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


function _init()
  bunny =
--[[pod_type="gfx"]]unpod("b64:bHo0AEIAAABZAAAA-wpweHUAQyAQEAQgF1AXQDcwNzAHHxcHMAceBAAHc7cwFwFnAQcGAPAJZx8OJ0CXcF8dkFeQFy4HkBcuB5AXEBdA")
  x = 232
  y = 10
  t = 0

  local m = fetch(DATP.."map/0.map")
  bg = m[1].bmp
  tiles = m[2].bmp
  fg = m[3].bmp

  apply_color_table(8)
  palt(0, true)
  vid(3)
end
 
function _draw()
  cls(1)   
  -- rrectfill(x+2,y+15,12,4,1,19) -- draw a 12x4 px shadow with colour 19 (dark green)
  local index = 17 + (t //20 ) % 4

  camera(x - C_X, y - C_Y)
  
  map(bg, 0, 0, 0 - x / 10)
  map(tiles, 0, 0)

  spr(0x30000 | index, x, y + (t//20%2), hflip) -- draw bunny; (x/8%2) is for hopping motion

  map(fg, 0, 0, x / 10)


  camera()
  local depth = math.log(y + 10) / 20
  for i = 1, 6 do 
    fillp(0xA5A5)
    circfill(C_X, C_Y, 20 + 5 * i / depth, 0x800000000 | 36)
    fillp()
    circfill(C_X, C_Y, 25 + 5 * i / depth, 0x800000000 | 36)
  end
end
 
function _update()
  local any_move = false
  if (btn(0))then any_move = true x = x - 2 hflip = true end
  if (btn(1))then any_move = true x = x + 2 hflip = false end
  if (btn(2))then any_move = true y = y - 2 end
  if (btn(3))then any_move = true y = y + 2 end

  if any_move then t = t + 1
  else t = t // 2 end
end
