local PLAYER_HALF_H = 0.7
local PLAYER_HALF_W = 0.2

-- todo diagonal bits to push against wall
local PLAYER_FEET_POINTS = {
  vec(-PLAYER_HALF_H, -PLAYER_HALF_W), 
  vec(-PLAYER_HALF_H, PLAYER_HALF_W),
}
local PLAYER_BODY_POINTS = {
  vec(0, -PLAYER_HALF_W), 
  vec(0, PLAYER_HALF_W),
}
local PLAYER_HEAD_POINTS = {
  vec(PLAYER_HALF_H * .5, -PLAYER_HALF_W), 
  vec(PLAYER_HALF_H, 0),
  vec(PLAYER_HALF_H * .5, PLAYER_HALF_W),
}
local PLAYER_ALL_POINTS = {}
for _,p in ipairs(PLAYER_FEET_POINTS) do add(PLAYER_ALL_POINTS, p) end
for _,p in ipairs(PLAYER_BODY_POINTS) do add(PLAYER_ALL_POINTS, p) end
for _,p in ipairs(PLAYER_HEAD_POINTS) do add(PLAYER_ALL_POINTS, p) end


---@class Player
---@field pos vec2
---@field t number
---@field dir integer quarter turns from angle 0. (0-3)
local Player = {}
Player.__index = Player

local function player_new(x, y, dir)
  local self = setmetatable({
    pos = vec(x, y),
    t = 0,
    dir = 0,
  }, Player)

  return self
end


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

  self.player = player_new(8, 4, 0)

  return self
end

function World:update()
  do -- player movement
    local p = self.player
    local any_move = false

    local dx = 0
    local dy = 0

    if (btn(0))then any_move = true dx = dx - 1 end
    if (btn(1))then any_move = true dx = dx + 1 end
    if (btn(2))then any_move = true dy = dy - 1 end
    if (btn(3))then any_move = true dy = dy + 1 end

    self:do_player_move(p, dx / 5, dy / 5)
    if any_move then
       p.t =  p.t + 1
    else
       p.t =  p.t // 2
    end
  end
end

function World:draw()
  cls(COLORS.BG)

  local p = self.player

  local p_pos = p.pos * TILE_FACTOR
  local cam_x = p_pos.x - CENTER_X
  local cam_y = p_pos.y - CENTER_Y
  camera(cam_x, cam_y)


  map(self.bg, 0, 0, 0 - p.pos.x / 10)
  map(self.tiles, 0, 0)

  local hflip = false
  local vflip = false
  local index = 16 + (p.t //20 ) % 4
  if p.dir == 1 or p.dir == 3 then index = index + 4 end
  if p.dir == 2 then hflip = true end
  if p.dir == 3 then vflip = true end
  spr(0x30000 | index, p_pos.x,  p_pos.y + ( p.t//20%2),  hflip, vflip)

  do -- debug points
    for i, o in ipairs(PLAYER_ALL_POINTS) do
      local step = vec_rot(o, p.dir/4)
      local tile_pos = p_pos + step * TILE_FACTOR
      pset(tile_pos.x, tile_pos.y, 8)
    end
  end
  

  map(self.fg, 0, 0, p.pos.x / 10)

  camera()
end

function World:try_move_player(p, dx, dy, dir, check_feet)

  local new_pos = p.pos + vec(dx, dy)
  
  local is_solid = false
  local is_push = false
  local all_air = true
  local push_dir
  local is_breathing = false
  for i, o in ipairs(PLAYER_BODY_POINTS) do
    local step = vec_rot(o, dir/4)
    local tile_pos = new_pos + step
    local tile = self.tiles:get(tile_pos.x, tile_pos.y)

    if fget(tile, 0) then
      is_solid = true
    end
    if not fget(tile, 1) then
      all_air = false
    end
  end
  for i, o in ipairs(PLAYER_FEET_POINTS) do
    local step = vec_rot(o, dir/4)
    local tile_pos = new_pos + step
    local tile = self.tiles:get(tile_pos.x, tile_pos.y)

    if fget(tile, 0) then
      if check_feet then
        is_solid = true
      end
    end
    if not fget(tile, 1) then
      all_air = false
    end
  end
  for i, o in ipairs(PLAYER_HEAD_POINTS) do
    local step = vec_rot(o, dir/4)
    local tile_pos = new_pos + step
    local tile = self.tiles:get(tile_pos.x, tile_pos.y)
    if fget(tile, 0) then
      if i == 1 or i == 3 then
        if not is_push then
          is_push = true
        else
          is_solid = true
        end
      else
        is_solid = true
      end
    end
    if fget(tile, 1) then
      is_breathing = true
    end
    if not fget(tile, 1) then
      all_air = false
    end
  end

  if is_solid or all_air then
    return
  end

  p.pos = new_pos
  p.dir = dir
end

function World:do_player_move(p, dx, dy)
  if dx ~= 0 or dy ~= 0 then
    local check_feet = false -- makes turning against walls nicer
    local new_dir = atan2(dx, dy)

    -- round to .25
    new_dir = flr(4 * new_dir + 0.5) % 4

    -- don't turn around hard
    if abs(p.dir - new_dir) == 2 then
      new_dir = p.dir
      dx = dx * 0.5
      dy = dy * 0.5
      check_feet = true
    end

    self:try_move_player(p, dx, 0, new_dir, check_feet)
    self:try_move_player(p, 0, dy, new_dir, check_feet)
  end

  local push_dir
  local is_push = false
  for i, o in ipairs(PLAYER_HEAD_POINTS) do
    local step = vec_rot(o, p.dir/4)
    local tile_pos = p.pos + step
    local tile = self.tiles:get(tile_pos.x, tile_pos.y)
    if fget(tile, 0) then
      if i == 1 or i == 3 then
        is_push = true
        if i == 1 then
          push_dir = (p.dir - 1) % 4
        elseif i == 3 then
          push_dir = (p.dir + 1) % 4
        end
      end
    end
  end
  if is_push then
    p.pos = p.pos + vec_rot(vec(.1, 0), push_dir / 4)
  end
end


return world
