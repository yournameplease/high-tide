local crab = require("crab.crab_gui.gui")
local layout = require("crab.crab_gui.layout")
local sw = require("crab.crab_gui.std_widgets")
local text_rendering = require("crab.crab_gui.text_rendering")
local font_cache = text_rendering.new_font_cache()
local dtm = require "src.util.draw_target_manager"

font_cache:add("widesquat", fetch("fonts/widesquat.font"))

local menu_style = text_rendering.default_style{col = COLORS.TEXT, halign = "center", valign = "center", primary_font = "widesquat"}
local menu_hover_style = text_rendering.default_style{col = COLORS.TEXT, halign = "center", valign = "center", primary_font = "widesquat"}

-- I ripped this from a WIP game of mine and hacked off the things I don't need here
-- this code is a mess now, avert your eyes

---@alias MenuDirection
---| "vertical"
---| "horizontal"
---| "grid"

---@class EntryOption
---@field text string
---@field value any

---@class MenuEntry
---@field type string
---@field text string
---@field key string
---@field default_value any,
---@field value any
---@field active boolean
 
---@class ListMenuEntry : MenuEntry
---@field type "list"
---@field index integer,
---@field options EntryOption,
 
---@class GridMenuEntry : MenuEntry
---@field type "grid"
---@field x integer
---@field y integer
---@field w integer
---@field h integer
---@field value_fn function(integer, integer): any
 
---@class ButtonMenuEntry : MenuEntry
---@field type "button"
---@field handler function()

---@class ToggleMenuEntry : MenuEntry
---@field type "toggle"
 
---@class Menu
---@field type string
---@field update function(self)
---@field layout function(self)
---@field get_value function(self, string): any
---@field set_value function(self, any)
---@field value_fn function(integer, integer): any
---@field index integer
---@field entries MenuEntry[]
---@field direction MenuDirection
local Menu = {}
Menu.__index = Menu

---@return fun():string, any
function Menu:pairs()
  local i = 0
  return function()
    while i < #self.entries do
      i = i + 1
      return self.entries[i].key, self.entries[i].value
    end
    return nil
  end
end

---@param key string
---@return any
function Menu:get_value(key)
  for _,e in ipairs(self.entries) do
    if e.key == key then
      return e.value
    end
  end
  return nil
end

function Menu:set_value(key, value)
  for _,e in ipairs(self.entries) do
    if e.key == key then
      if e.type == "list" then
        ---@cast e ListMenuEntry
        for i,o in ipairs(e.options) do
          if o.value == value then
            e.index = i
            e.value = value
          end
        end
      elseif e.type == "grid" then
        ---@cast e GridMenuEntry
        for x = 0, e.w - 1 do
          for y = 0, e.h - 1 do
            if e.value_fn(x, y) == value then
              e.x = x
              e.y = y
              e.value = value
            end
          end
        end
      end
    end
  end
end

function Menu:set_default()
  log.debug("setting default", self, #self.entries)
  for _,e in ipairs(self.entries) do
    if e.type == "list" then
      ---@cast e ListMenuEntry
      if e.default_value then
        for i,o in ipairs(e.options) do
          if o.value == e.default_value then
            e.index = i
            e.value = e.default_value
          end
        end
      else
      log.debug("setting 1")
        e.index = 1
        e.value = e.options[1].value
      end
    elseif e.type == "grid" then
      ---@cast e GridMenuEntry
      if e.default_value then
        for x = 0, e.w - 1 do
          for y = 0, e.h - 1 do
            if e.value_fn(x, y) == e.default_value then
              e.x = x
              e.y = y
              e.value = e.default_value
            end
          end
        end
      else
      log.debug("setting 0,0")
        e.x = 0
        e.y = 0
        e.value = e.value_fn(0, 0)
      end
    end
  end
end

local menu = {}

---@param m Menu
function menu.set_default(m)
  m:set_default()
end

---@param direction MenuDirection
---@param entries MenuEntry[]
---@return Menu
function menu.new_list(
  direction,
  entries
)
  local self = setmetatable({
    type = "list",
    direction = direction,
    entries = entries,
    index = 1,
  }, Menu)

  for _,e in ipairs(entries) do
    if e.type == "list" then
      e.value = e.options[1].value
    elseif e.type == "grid" then
      e.value = e.value_fn(e.x, e.y)
    end
  end
  return self
end

function menu.count_fn(w, h)
  return function(x, y)
    return y * w + x
  end
end

function menu.string_options(
  entries
)
  local options = {}
  for i, v in ipairs(entries) do
    options[i] = {
      text = v,
      value = v,
    }
  end
  return options
end

function menu.boolean_options(
)
  return {
    {value = true, text = "true"},
    {value = false, text = "false"},
  }
end

---@param key string
---@param options EntryOption[]
---@return ListMenuEntry
function menu.list_entry(
  key,
  options
)
  return {
    type = "list",
    key = key,
    text = key,
    index = 1,
    options = options,
  }
end

---@param key string
---@return GridMenuEntry
function menu.grid_entry(
  key,
  w,
  h,
  value_fn,
  x,
  y,
  default_value
)
  return {
    type = "grid",
    key = key,
    text = key,
    x = x or 0,
    y = y or 0,
    w = w,
    h = h,
    value_fn = value_fn,
    default_value = default_value,
  }
end

---@param key string
---@param handler function()
---@return ButtonMenuEntry
function menu.button(
  key,
  handler
)
  return {
    type = "button",
    key = key,
    text = key,
    handler = handler
  }
end

---@param key string
---@return ToggleMenuEntry
function menu.toggle(
  key,
  value
)
  return {
    type = "toggle",
    key = key,
    text = key,
    value = value,
  }
end

--@return boolean value_change
function Menu:update()
  local value_change = false

  local entry = self.entries[self.index]
  if entry.type == "grid" and entry.active then
    ---@cast entry GridMenuEntry
    if btnp(2) then entry.y = entry.y - 1 end
    if btnp(3) then entry.y = entry.y + 1 end
    if btnp(0) then entry.x = entry.x - 1 end
    if btnp(1) then entry.x = entry.x + 1 end

    entry.x = mid(0, entry.x, entry.w - 1)
    entry.y = mid(0, entry.y, entry.h - 1)

    if btnp(4) then
      entry.value = entry.value_fn(entry.x, entry.y)
      entry.active = false
      return true
    end
  else
    if self.direction == "vertical" then
      local step = 0
      if btnp(2) then step = step - 1 end
      if btnp(3) then step = step + 1 end

      self.index = self.index + step
    else
      error()
    end
  end

  self.index = mod_t(self.index, #self.entries)
  entry = self.entries[self.index]

  if entry.type == "list" then
    ---@cast entry ListMenuEntry
    if btnp(0) then
      value_change = true
      entry.index = entry.index - 1
    end
    if btnp(1) then
      value_change = true
      entry.index = entry.index + 1
    end

    if value_change then
      entry.index = mod_t(entry.index, #entry.options)
      entry.value = entry.options[entry.index].value
    end
  elseif entry.type == "grid" then
    ---@cast entry GridMenuEntry
    if btnp(4) then
      entry.active = true
    end
  elseif entry.type == "button" then
    ---@cast entry ButtonMenuEntry
    if btnp(4) then
      entry.handler(self)
      value_change = true
    end
  elseif entry.type == "toggle" then
    ---@cast entry ButtonMenuEntry
    if btnp(4) then
      entry.value = not entry.value
      value_change = true
    end
  elseif entry.type == "accordion" then
    ---@cast entry AccordionMenuEntry
    if btnp(4) then
      entry.active = not entry.active
    end
  else
    error()
  end

  return value_change 
end

function Menu:layout(gui)
  local is_collapsed = false
  
  local CELL_SIDE = 4
  local entries = self.entries
  local index = self.index
  
	gui:push_rect(layout.new_rect_at(
		vec(0.5, 0.5),
		vec(SCREEN_W - 2*THEME.UI_PAD, SCREEN_H - 2*THEME.UI_PAD)
	))

	local anchors = {}
	local heights = {}
	local full_h = 0
	for i,e in ipairs(entries) do
	  local addend = 0
	  if e.type == "accordion" then
      is_collapsed = not e.active
      addend = THEME.ROW_H
	  elseif not is_collapsed then
  	  if e.type == "grid" and e.active then
  	    ---@cast e GridMenuEntry
  	    addend = CELL_SIDE * e.h
      else
        addend = THEME.ROW_H
      end
    end
    -- anchors[i] = full_h + addend/2
    anchors[i] = full_h
    heights[i] = addend
    full_h = full_h + addend
  end
	for i,v in ipairs(anchors) do
    anchors[i] = (v + heights[i] * (i-1) / (#anchors-1)) / full_h
  end
	full_h = full_h + 2*THEME.PANEL_PAD
	
  local BOX_WIDTH = 130
  
  is_collapsed = false
  
	gui:push_rect(layout.new_rect_at(
		vec(0.5, 0.75),
		vec(BOX_WIDTH, full_h)
	))
	gui:push_rect(layout.new_rect_at(
		vec(0.5, 0.5),
		vec(BOX_WIDTH-2*THEME.PANEL_PAD, full_h-2*THEME.PANEL_PAD)
	))
	for i,e in ipairs(entries) do
    if e.type == "accordion" then
      is_collapsed = not e.active
    elseif is_collapsed then
      goto continue
    end
	  
  	gui:push_rect(layout.new_rect_at(
  		vec(0.5, anchors[i]),
  		vec(BOX_WIDTH-2*THEME.PANEL_PAD, THEME.ROW_H)
  	))


  	local LABEL_FAC = 0.5
    
  	if e.type ~= "button" then
    	gui:push_rect(layout.new_rect_at(
    		vec(0., 0.5),
    		vec(BOX_WIDTH * LABEL_FAC -2*THEME.PANEL_PAD, THEME.ROW_H)
    	))
    	sw.text(gui, font_cache, e.text, menu_style)
    	gui:pop_rect()
  	end
  	

  	local is_hovered = index == i
  	if e.type == "list"
  	  or (e.type == "grid" and not e.active)
  	  or e.type == "toggle" then
    	gui:push_rect(layout.new_rect_at(
    		vec(1., 0.5),
    		vec(BOX_WIDTH * (1-LABEL_FAC) -2*THEME.PANEL_PAD, THEME.ROW_H)
    	))

      	-- local txt = tostr(o.options[o.index])
      	local txt = tostr(e.value)
      	if e.type == "toggle" then
        	txt = e.value and "[X]" or "[ ]"
    	  else
        	txt = chr(139) .. txt .. chr(145)
    	  end

        if is_hovered then
          sw.panel(gui, COLORS.BG + 1, 3)
        	sw.text(gui, font_cache, txt, menu_hover_style)
        else
        	sw.text(gui, font_cache, txt, menu_style)
      	end
    	gui:pop_rect()
  	elseif e.type == "button" then
    	gui:push_rect(layout.new_rect_at(
    		vec(0.5, 0.5),
    		vec(BOX_WIDTH -2*THEME.PANEL_PAD, THEME.ROW_H)
    	))
      	local text = e.text
        if is_hovered then
        	sw.text(gui, font_cache, "> " .. text .. " <", menu_hover_style)
      	else
        	sw.text(gui, font_cache, text, menu_style)
      	end
        -- sw.panel(gui, 7, 3)
    	gui:pop_rect()
  	end

  	gui:pop_rect()
  	::continue::
	end

	gui:pop_rect()
	gui:pop_rect()
	gui:pop_rect()
end

return menu

