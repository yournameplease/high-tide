local dtm = require "src.util.draw_target_manager"

-- TODO: this is laggy (and confusing)
-- TODO: colortable to allow lights to merge (high light > low light)

local LIGHT_BASE = 0
local LIGHT_N = 4
local LIGHT_MAX = LIGHT_BASE + LIGHT_N - 1

local light_buffer = userdata("u8", SCREEN_W, SCREEN_H)

local lighting = {}

function lighting.clear()
  light_buffer:band(0, true)
end

function lighting.light_rows(y, h)
  dtm.push_target(light_buffer)
  -- doesn't work
  for i = LIGHT_N, 1, -1 do 
    rrectfill(0, y + h * i, SCREEN_W, -SCREEN_H, LIGHT_N - i + 1)
  end
  dtm.pop()
end

function lighting.light_disks(x, y, r, dr)
  dtm.push_target(light_buffer)
  for i = LIGHT_N, 1, -1 do 
    circfill(x, y, r + dr * i, LIGHT_N - i + 1)
  end
  dtm.pop()
end

function lighting.draw_lighting()
  -- this is stupid.
  light_buffer.sub(36, light_buffer, light_buffer)
  light_buffer:min(36, true)

  for c = 1, 35 do
    palt(c, true)
  end
  
  local dither = false
  for i = 1, LIGHT_N - 1 do 
    local c = LIGHT_BASE + i

    if dither then
      fillp(0xA5A5)
    else
      fillp()
    end

    dither = not dither

    spr(light_buffer)
    light_buffer:add(1, true)
    light_buffer:min(36, true)
  end

  for c = 1, 35 do
    palt(c, false)
  end
  for c = LIGHT_BASE, LIGHT_N do
    -- palt(c, false)
  end
  -- palt()
end

return lighting
