
---@class DrawTargetEntry
---@field ud userdata
---@field camera_x integer
---@field camera_y integer

---@type DrawTargetEntry[]
local targets = {}
---@type DrawTargetEntry?
local current_target = nil

local draw_target_manager = {}

local function apply_current_target()
    if current_target ~= nil then
        set_draw_target(current_target.ud)
        camera(current_target.camera_x, current_target.camera_y)
    else
        set_draw_target()
        camera()
    end
end

---@param w integer
---@param h integer
---@param camera_x? integer
---@param camera_y? integer
function draw_target_manager.push_new_target(w, h, camera_x, camera_y)
    local ud = userdata("u8", w, h)
    draw_target_manager.push_target(ud, camera_x, camera_y)
end

---@param ud userdata
---@param camera_x? integer
---@param camera_y? integer
function draw_target_manager.push_target(ud, camera_x, camera_y)
    local new_target = {
        ud = ud,
        camera_x = camera_x and -camera_x or 0,
        camera_y = camera_x and -camera_y or 0,
    }

    if current_target ~= nil then
        add(targets, current_target)
    end
    current_target = new_target
    apply_current_target()
end

--- pop and draw the current target at x, y
---@param x integer
---@param y integer
function draw_target_manager.draw(x, y)
    assert(current_target ~= nil, "tried to pop an empty draw target")

    local prev_target = current_target
    current_target = table.remove(targets)
    apply_current_target()

    spr(prev_target.ud, x, y)
end

--- pop the current target
---@return userdata
function draw_target_manager.pop()
    assert(current_target ~= nil, "tried to pop an empty draw target")

    local prev_target = current_target
    current_target = table.remove(targets)
    apply_current_target()

    return prev_target.ud
end

return draw_target_manager
