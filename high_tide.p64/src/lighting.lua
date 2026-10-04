local dtm = require "src.util.draw_target_manager"

-- this is still a bit laggy.  consider perf optimizations if frames drop

local DARK_BASE = COLORS.DARK[1]
local DARK_N = 4
local DARK_MAX = DARK_BASE + DARK_N

local light_buffer = userdata("u8", SCREEN_W, SCREEN_H)

local lighting = {}

function lighting.clear()
  light_buffer:copy(DARK_MAX, true)
end

function lighting.light_rows(y, h)
  dtm.push_target(light_buffer)
  for i = DARK_N, 0, -1 do 
    rrectfill(0, y + h * i, SCREEN_W, h,0, DARK_BASE + i)
  end
  dtm.pop()
end

function lighting.light_disks(x, y, r, dr)
  dtm.push_target(light_buffer)
  for i = DARK_N, 0, -1 do 
    circfill(x, y, r + dr * i, DARK_BASE + i)
  end
  dtm.pop()
end

function lighting.light_cone(x1, y1, r1, x2, y2, r2, steps, light_level)
  dtm.push_target(light_buffer)
  for i = 0, steps-1 do
    local x = lerp(i/(steps-1), x1, x2)
    local y = lerp(i/(steps-1), y1, y2)
    local r = lerp(i/(steps-1), r1, r2)
    circfill(x, y, r, DARK_BASE + light_level)
  end
  dtm.pop()
end

function lighting.draw_lighting()
  spr(light_buffer)
end

return lighting
