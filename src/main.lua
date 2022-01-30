local Common = require "Common"

io.stdout:setvbuf("no") -- This makes is so that print() statements print right away.

local sprite = {
  size = {x = 59, y = 24},
  pivot = {x = 29, y = 24}
}

local KeyboardState = {
  selected = "origin",
  move_up = false,
  move_down = false,
  move_left = false,
  move_right = false,
  rotate_cw = false,
  rotate_ccw = false
}

local origin = {}
local destination = {}

local window_width, window_height = 768, 768
local turning_radius = 95

local function update_truck(truck)
  truck.left = Common.vector_rotate({x = 1, y = 0}, Common.over_2pi(math.pi / 2 + truck.orientation))
  truck.right = Common.vector_rotate({x = 1, y = 0}, Common.over_2pi(-(math.pi / 2) + truck.orientation))
  truck.head = Common.vector_rotate({x = 1, y = 0}, truck.orientation)

  truck.left_center = Common.vector_add(Common.vector_mul(truck.left, turning_radius), truck.position)
  truck.right_center = Common.vector_add(Common.vector_mul(truck.right, turning_radius), truck.position)
end

local function init_truck(truck)
  truck.orientation = 0

  update_truck(truck)
end

function love.load(args)
  love.window.setMode(window_width, window_height, {resizable = false})

  origin = {
    position = {x = window_width / 4, y = window_height / 2},
    image = love.graphics.newImage("assets/truck_origin.png")
  }

  destination = {
    position = {x = window_width * 3 / 4, y = window_height / 2},
    image = love.graphics.newImage("assets/truck_destination.png")
  }

  init_truck(origin)
  init_truck(destination)
end

local function update_keyboard_state()
  if love.keyboard.isDown("i") then
    KeyboardState.selected = "origin"
  end
  if love.keyboard.isDown("o") then
    KeyboardState.selected = "destination"
  end

  KeyboardState.move_up = love.keyboard.isDown("w")
  KeyboardState.move_down = love.keyboard.isDown("s")
  KeyboardState.move_left = love.keyboard.isDown("a")
  KeyboardState.move_right = love.keyboard.isDown("d")
  KeyboardState.rotate_cw = love.keyboard.isDown("down")
  KeyboardState.rotate_ccw = love.keyboard.isDown("up")
end

local function get_arc_data(center, radius, start, finish)
  local normalized_start, start_length = Common.vector_normalize(Common.vector_sub(start, center))
  local normalized_finish, finish_length = Common.vector_normalize(Common.vector_sub(finish, center))

  if not Common.equivalent(start_length, radius) then
    print("expected the start_length to be similar to radius...", radius, " != ", start_length)
  end
  if not Common.equivalent(finish_length, radius) then
    print("expected the finish_length to be similar to radius...", radius, " != ", finish_length)
  end

  local angle_start = math.atan2(normalized_start.y, normalized_start.x)
  local angle_finish = math.atan2(normalized_finish.y, normalized_finish.x)

  return Common.over_2pi(angle_finish - angle_start) * radius, Common.over_2pi(angle_start), Common.over_2pi(
    angle_finish
  )
end

local function dubins_LSL()
  local center_to_center_segment = Common.vector_sub(destination.left_center, origin.left_center)
  local center_to_center_direction, center_to_center_length = Common.vector_normalize(center_to_center_segment)

  local departure_offset =
    Common.vector_mul(Common.vector_rotate(center_to_center_direction, -math.pi / 2), turning_radius)

  local leave_point = Common.vector_add(departure_offset, origin.left_center)
  local entry_point = Common.vector_add(leave_point, center_to_center_segment)

  local segment_1_length, origin_angle_in, origin_angle_out =
    get_arc_data(origin.left_center, turning_radius, origin.position, leave_point)
  local segment_3_length, destination_angle_in, destination_angle_out =
    get_arc_data(destination.left_center, turning_radius, entry_point, destination.position)

  return {
    leave_point = leave_point,
    entry_point = entry_point,
    origin_angles = {start = origin_angle_in, finish = origin_angle_out},
    destination_angles = {start = destination_angle_in, finish = destination_angle_out},
    segments_lengths = {
      segment_1_length,
      center_to_center_length,
      segment_3_length
    },
    segments_length_total = segment_1_length + center_to_center_length + segment_3_length
  }
end

function love.update(dt)
  update_keyboard_state()

  local updateable
  if KeyboardState.selected == "origin" then
    updateable = origin
  else
    updateable = destination
  end

  if KeyboardState.move_down then
    updateable.position.y = updateable.position.y + 1
  end
  if KeyboardState.move_up then
    updateable.position.y = updateable.position.y - 1
  end
  if KeyboardState.move_left then
    updateable.position.x = updateable.position.x - 1
  end
  if KeyboardState.move_right then
    updateable.position.x = updateable.position.x + 1
  end
  if KeyboardState.rotate_cw then
    updateable.orientation = updateable.orientation - (math.pi / 64)
  end
  if KeyboardState.rotate_ccw then
    updateable.orientation = updateable.orientation + (math.pi / 64)
  end

  updateable.orientation = Common.over_2pi(updateable.orientation)

  update_truck(origin)
  update_truck(destination)
end

function love.keyreleased(key)
  if key == "escape" then
    love.event.quit()
  end
end

-- https://love2d.org/wiki/LineStippleSnippet
local function lineStipple(x1, y1, x2, y2, dash, gap)
  local dash = dash or 10
  local gap = dash + (gap or 10)

  local steep = math.abs(y2 - y1) > math.abs(x2 - x1)
  if steep then
    x1, y1 = y1, x1
    x2, y2 = y2, x2
  end
  if x1 > x2 then
    x1, x2 = x2, x1
    y1, y2 = y2, y1
  end

  local dx = x2 - x1
  local dy = math.abs(y2 - y1)
  local err = dx / 2
  local ystep = (y1 < y2) and 1 or -1
  local y = y1
  local maxX = x2
  local pixelCount = 0
  local isDash = true
  local lastA, lastB, a, b

  for x = x1, maxX do
    pixelCount = pixelCount + 1
    if (isDash and pixelCount == dash) or (not isDash and pixelCount == gap) then
      pixelCount = 0
      isDash = not isDash
      a = steep and y or x
      b = steep and x or y
      if lastA then
        love.graphics.line(lastA, lastB, a, b)
        lastA = nil
        lastB = nil
      else
        lastA = a
        lastB = b
      end
    end

    err = err - dy
    if err < 0 then
      y = y + ystep
      err = err + dx
    end
  end
end

local function draw_one(truck, colour)
  love.graphics.draw(
    truck.image,
    truck.position.x,
    truck.position.y,
    truck.orientation,
    1,
    1,
    sprite.pivot.x,
    sprite.pivot.y
  )
  love.graphics.setColor(colour.r, colour.g, colour.b)
  love.graphics.circle("fill", truck.position.x, truck.position.y, 5)

  love.graphics.setColor(0, 1, 0)
  love.graphics.line(truck.position.x, truck.position.y, truck.left_center.x, truck.left_center.y)

  love.graphics.setColor(1, 0, 0)
  love.graphics.line(truck.position.x, truck.position.y, truck.right_center.x, truck.right_center.y)

  love.graphics.setColor(0, 0.25, 0)
  love.graphics.circle("line", truck.left_center.x, truck.left_center.y, turning_radius)

  love.graphics.setColor(0.25, 0, 0)
  love.graphics.circle("line", truck.right_center.x, truck.right_center.y, turning_radius)

  love.graphics.setColor(0.25, 0.25, 0.25)
  local start = Common.vector_add(Common.vector_mul(truck.head, 200), truck.position)
  local finish = Common.vector_add(Common.vector_mul(truck.head, -200), truck.position)
  --love.graphics.line(start.x, start.y, finish.x, finish.y)
  lineStipple(start.x, start.y, finish.x, finish.y)

  love.graphics.setColor(1, 1, 1)
end

function love.draw()
  -- drawing the origin
  draw_one(origin, {r = 1, g = 1, b = 0})

  -- drawing the destination
  draw_one(destination, {r = 0, g = 0, b = 1})

  local lsl_data = dubins_LSL()

  -- return {
  --   leave_point = leave_point,
  --   entry_point = entry_point,
  --   origin_angles = {start = origin_angle_in, finish = origin_angle_out},
  --   destination_angles = {start = destination_angle_in, finish = destination_angle_out},
  --   segments_lengths = {
  --     segment_1_length,
  --     center_to_center_length,
  --     segment_3_length},
  --   segments_length_total = segment_1_length + center_to_center_length + segment_3_length
  -- }

  love.graphics.line(lsl_data.leave_point.x, lsl_data.leave_point.y, lsl_data.entry_point.x, lsl_data.entry_point.y)
  -- If the starting angle is numerically bigger than the final angle, the arc is drawn counter clockwise.
  -- If the final angle is numerically bigger than the starting angle, the arc is drawn clockwise.
  local draw_start
  local draw_finish
  if lsl_data.origin_angles.start > lsl_data.origin_angles.finish then
    draw_start = lsl_data.origin_angles.start
    draw_finish = lsl_data.origin_angles.finish + math.pi * 2
  else
    draw_start = lsl_data.origin_angles.start
    draw_finish = lsl_data.origin_angles.finish
  end

  love.graphics.arc("line", "open", origin.left_center.x, origin.left_center.y, turning_radius, draw_start, draw_finish)

  -- "end"
  if lsl_data.destination_angles.start > lsl_data.destination_angles.finish then
    draw_start = lsl_data.destination_angles.start
    draw_finish = lsl_data.destination_angles.finish + math.pi * 2
  else
    draw_start = lsl_data.destination_angles.start
    draw_finish = lsl_data.destination_angles.finish
  end

  love.graphics.arc(
    "line",
    "open",
    destination.left_center.x,
    destination.left_center.y,
    turning_radius,
    draw_start,
    draw_finish
  )
end
