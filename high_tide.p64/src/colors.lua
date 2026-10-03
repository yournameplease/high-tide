local BASE_COLOR = 32

local AZURE_ABYSS = {
  0x10022a,
  0x0e033e,
  0x04055d,
  0x002c7b,
  0x004a9b,
  0x0076af,
  0x00a3ca,
  0x00c6bf,
  0x69f0c7,
}

local ASTRIDA_SOLSETURS = {
  0x05051b,
  0x1b0a27,
  0x411d34,
  0x672142,
  0x8d2c30,
  0xca7125,
  0xe7d37d,
  0xeef2ba,
  0xfefef8,
}

--these numbers make no sense to me.  curse you, 1-indexing

local BLUE_START = BASE_COLOR
local BLUE_END = BLUE_START + #AZURE_ABYSS

local WHITE_START = BLUE_END + 1
local WHITE_END = WHITE_START + #ASTRIDA_SOLSETURS

local COLORTABLE_BASE = WHITE_END + 1

COLORS = {
  DARK = {
    -- darken by N tones
  },
  BG = 36,
}

for i = 1, 9 do
  COLORS.DARK[i] = COLORTABLE_BASE + i - 1
end

assert(COLORTABLE_BASE + #COLORS.DARK < 64, "too many colors!  move them around")

local colors = {}

function colors.build_color_palette()
  for i, c in ipairs(AZURE_ABYSS) do
    pal(BASE_COLOR + i, c, 2)
  end 
  for i, c in ipairs(ASTRIDA_SOLSETURS) do
    pal(BASE_COLOR + #AZURE_ABYSS + i, c, 2)
  end

  local out = userdata("i32", 64):peek(0x005000)
  store("/ram/shared/default.pal", out)

  --- colortable
  local colortable = userdata("u8", 64, 64):peek(0x8000)

  for i,c in ipairs(COLORS.DARK) do
    -- darken each of our custom colors by i steps
    for j = BLUE_START, BLUE_END do
      colortable:set(j, c, max(j - i, BLUE_START))
    end
    for j = WHITE_START, WHITE_END do
      colortable:set(j, c, max(j - i, WHITE_START))
    end
  end

  poke(0x8000, colortable)
  -- set_spr(1, colortable)
  set_clipboard(pod(colortable, 0x0, {pod_type="image"}))

	--poke the bit that makes colortable work for shapes(circ,rect etc.), the bit for sprites
	--is already set by default.
	poke(0x550b,0x3f)
end

return colors
