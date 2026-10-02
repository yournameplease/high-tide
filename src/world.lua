---@class Player
---@field x number
---@field y number
---@field t number

---@class World
---@field bg userdata
---@field tiles userdata
---@field fg userdata

local World = {}
World.__index = World

local world = {}


function world.new(map_path)
  local self = setmetatable({}, World)

  local m = fetch(map_path)
  self.bg = m[1].bmp
  self.tiles = m[2].bmp
  self.fg = m[3].bmp

  self.player = {
    x = 200,
    y = 10,
    t = 0,
  }

  return self
end

function World:update()

  do -- player movement
    local p = self.player
    local any_move = false
  
    if (btn(0))then any_move = true p.x = p.x - 2 p.hflip = true end
    if (btn(1))then any_move = true p.x = p.x + 2 p.hflip = false end
    if (btn(2))then any_move = true p.y = p.y - 2 end
    if (btn(3))then any_move = true p.y = p.y + 2 end

    if any_move then
       p.t =  p.t + 1
    else
       p.t =  p.t // 2
    end
  end
end

function World:draw()
  cls(1)

  local p = self.player

  local cam_x = p.x - CENTER_X
  local cam_y = p.y - CENTER_Y
  camera(cam_x, cam_y)


  map(self.bg, 0, 0, 0 - p.x / 10)
  map(self.tiles, 0, 0)

  local index = 17 + (p.t //20 ) % 4
  spr(0x30000 | index, p.x,  p.y + ( p.t//20%2),  p.hflip)

  map(self.fg, 0, 0, p.x / 10)

  camera()
end

return world
