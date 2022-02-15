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

--- Computes the arc between a starting point and a finishing point on a circle.
-- The function expects:
-- - that the start and finish are in counter-clock-wise order.
-- - that the angles are all in the range of [0, 2pi[, with 0 being on x+
--
-- If the points presented don't appear to be on the circle, math.huge is returned for all the values.
--
-- @param center table ({x:, y:}) of the coordinates of the center of the circle.
-- @param radius number value of the radius of the circle
-- @param start table ({x:, y:}) of a point on the circle where the angle "starts"; should be on the circle edge.
-- @param finish table ({x:, y:}) of a point on the circle where the angle "finishes"; should be on the circle edge.
-- 
-- @return angle between the two points, or math.huge if both points are not on the circle edge.
-- @return the angle where start is, or math.huge if both points are not on the circle edge.
-- @return the angle where finish is, or math.hug if both points are not on the circle edge.
local function get_arc_data(center, radius, start, finish)
  local normalized_start, start_length = Common.vector_normalize(Common.vector_sub(start, center))
  local normalized_finish, finish_length = Common.vector_normalize(Common.vector_sub(finish, center))

  if not Common.equivalent(start_length, radius) or not Common.equivalent(finish_length, radius) then
    return math.huge, math.huge, math.huge
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

local function dubins_RSR()
  local center_to_center_segment = Common.vector_sub(destination.right_center, origin.right_center)
  local center_to_center_direction, center_to_center_length = Common.vector_normalize(center_to_center_segment)

  local departure_offset =
    Common.vector_mul(Common.vector_rotate(center_to_center_direction, math.pi / 2), turning_radius)

  local leave_point = Common.vector_add(departure_offset, origin.right_center)
  local entry_point = Common.vector_add(leave_point, center_to_center_segment)

  local segment_1_length, origin_angle_in, origin_angle_out =
    get_arc_data(origin.right_center, turning_radius, origin.position, leave_point)
  local segment_3_length, destination_angle_in, destination_angle_out =
    get_arc_data(destination.right_center, turning_radius, entry_point, destination.position)

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

local function dubins_LSR()
  local center_to_center_segment = Common.vector_sub(destination.right_center, origin.left_center)
  local center_to_center_direction, center_to_center_length = Common.vector_normalize(center_to_center_segment)

  local straight_length =
    math.sqrt(center_to_center_length * center_to_center_length - turning_radius * 2 * turning_radius * 2)

  local angle_center_to_center___leave_point = -math.acos((turning_radius * 2) / center_to_center_length)

  local leave_point_direction = Common.vector_rotate(center_to_center_direction, angle_center_to_center___leave_point)
  local leave_point_vector = Common.vector_mul(leave_point_direction, turning_radius)

  local leave_point = Common.vector_add(origin.left_center, leave_point_vector)

  local straight_direction, _ =
    Common.vector_normalize(Common.vector_rotate(Common.vector_sub(origin.left_center, leave_point), -math.pi / 2))

  local entry_point = Common.vector_add(leave_point, Common.vector_mul(straight_direction, straight_length))

  local segment_1_length, origin_angle_in, origin_angle_out =
    get_arc_data(origin.left_center, turning_radius, origin.position, leave_point)
  local segment_3_length, destination_angle_in, destination_angle_out =
    get_arc_data(destination.right_center, turning_radius, entry_point, destination.position)

  return {
    leave_point = leave_point,
    entry_point = entry_point,
    origin_angles = {start = origin_angle_in, finish = origin_angle_out},
    destination_angles = {start = destination_angle_in, finish = destination_angle_out},
    segments_lengths = {
      segment_1_length,
      straight_length,
      segment_3_length
    },
    segments_length_total = segment_1_length + straight_length + segment_3_length
  }
end

local function dubins_RSL()
  local center_to_center_segment = Common.vector_sub(destination.left_center, origin.right_center)
  local center_to_center_direction, center_to_center_length = Common.vector_normalize(center_to_center_segment)

  local straight_length =
    math.sqrt(center_to_center_length * center_to_center_length - turning_radius * 2 * turning_radius * 2)

  local angle_center_to_center___leave_point = math.acos((turning_radius * 2) / center_to_center_length)

  local leave_point_direction = Common.vector_rotate(center_to_center_direction, angle_center_to_center___leave_point)
  local leave_point_vector = Common.vector_mul(leave_point_direction, turning_radius)

  local leave_point = Common.vector_add(origin.right_center, leave_point_vector)

  local straight_direction, _ =
    Common.vector_normalize(Common.vector_rotate(Common.vector_sub(origin.right_center, leave_point), math.pi / 2))

  local entry_point = Common.vector_add(leave_point, Common.vector_mul(straight_direction, straight_length))

  local segment_1_length, origin_angle_in, origin_angle_out =
    get_arc_data(origin.right_center, turning_radius, origin.position, leave_point)
  local segment_3_length, destination_angle_in, destination_angle_out =
    get_arc_data(destination.left_center, turning_radius, entry_point, destination.position)

  return {
    leave_point = leave_point,
    entry_point = entry_point,
    origin_angles = {start = origin_angle_in, finish = origin_angle_out},
    destination_angles = {start = destination_angle_in, finish = destination_angle_out},
    segments_lengths = {
      segment_1_length,
      straight_length,
      segment_3_length
    },
    segments_length_total = segment_1_length + straight_length + segment_3_length
  }
end

local function dubins_RLR()
  local center_to_center_segment = Common.vector_sub(destination.right_center, origin.right_center)
  local center_to_center_direction, center_to_center_length = Common.vector_normalize(center_to_center_segment)
  local angle_destination_center_new_circle_center
  if (2 * turning_radius) > (center_to_center_length / 2) then
    angle_destination_center_new_circle_center = math.acos((center_to_center_length / 2) / (2 * turning_radius))
  else
    angle_destination_center_new_circle_center = math.acos((2 * turning_radius) / (center_to_center_length / 2))
  end

  local new_circle_center =
    Common.vector_add(
    origin.right_center,
    Common.vector_rotate(
      Common.vector_mul(center_to_center_direction, 2 * turning_radius),
      -angle_destination_center_new_circle_center
    )
  )

  local leave_point =
    Common.vector_add(
    origin.right_center,
    Common.vector_mul(Common.vector_sub(new_circle_center, origin.right_center), 0.5)
  )
  local entry_point =
    Common.vector_add(
    new_circle_center,
    Common.vector_mul(Common.vector_sub(destination.right_center, new_circle_center), 0.5)
  )

  local segment_1_length, origin_angle_in, origin_angle_out =
    get_arc_data(origin.right_center, turning_radius, origin.position, leave_point)
  local segment_3_length, destination_angle_in, destination_angle_out =
    get_arc_data(destination.right_center, turning_radius, entry_point, destination.position)

  local segment_2_length, center_angle_in, center_angle_out =
    get_arc_data(new_circle_center, turning_radius, leave_point, entry_point)

  --print("RLR segment_2_length ", segment_2_length)

  return {
    leave_point = leave_point,
    entry_point = entry_point,
    origin_angles = {start = origin_angle_in, finish = origin_angle_out},
    destination_angles = {start = destination_angle_in, finish = destination_angle_out},
    segments_lengths = {
      segment_1_length,
      segment_2_length,
      segment_3_length
    },
    segments_length_total = segment_1_length + segment_2_length + segment_3_length,
    ccc_center = {
      center = new_circle_center,
      angles = {
        start = center_angle_in,
        finish = center_angle_out
      }
    }
  }
end

local function dubins_LRL()
  local center_to_center_segment = Common.vector_sub(destination.left_center, origin.left_center)
  local center_to_center_direction, center_to_center_length = Common.vector_normalize(center_to_center_segment)
  local angle_destination_center_new_circle_center
  if (2 * turning_radius) > (center_to_center_length / 2) then
    angle_destination_center_new_circle_center = -math.acos((center_to_center_length / 2) / (2 * turning_radius))
  else
    angle_destination_center_new_circle_center = -math.acos((2 * turning_radius) / (center_to_center_length / 2))
  end

  local new_circle_center =
    Common.vector_add(
    origin.left_center,
    Common.vector_rotate(
      Common.vector_mul(center_to_center_direction, 2 * turning_radius),
      -angle_destination_center_new_circle_center
    )
  )

  local leave_point =
    Common.vector_add(
    origin.left_center,
    Common.vector_mul(Common.vector_sub(new_circle_center, origin.left_center), 0.5)
  )
  local entry_point =
    Common.vector_add(
    new_circle_center,
    Common.vector_mul(Common.vector_sub(destination.left_center, new_circle_center), 0.5)
  )

  local segment_1_length, origin_angle_in, origin_angle_out =
    get_arc_data(origin.left_center, turning_radius, origin.position, leave_point)
  local segment_3_length, destination_angle_in, destination_angle_out =
    get_arc_data(destination.left_center, turning_radius, entry_point, destination.position)

  local segment_2_length, center_angle_in, center_angle_out =
    get_arc_data(new_circle_center, turning_radius, leave_point, entry_point)

  --print("LRL segment_2_length ", segment_2_length)

  return {
    leave_point = leave_point,
    entry_point = entry_point,
    origin_angles = {start = origin_angle_in, finish = origin_angle_out},
    destination_angles = {start = destination_angle_in, finish = destination_angle_out},
    segments_lengths = {
      segment_1_length,
      segment_2_length,
      segment_3_length
    },
    segments_length_total = segment_1_length + segment_2_length + segment_3_length,
    ccc_center = {
      center = new_circle_center,
      angles = {
        start = center_angle_in,
        finish = center_angle_out
      }
    }
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
  local rsr_data = dubins_RSR()
  local rsl_data = dubins_RSL()
  local lsr_data = dubins_LSR()
  local lrl_data = dubins_LRL()
  local rlr_data = dubins_RLR()

  -- print(
  --   "lsl ", lsl_data.segments_length_total, " ",
  --   "rsr ", rsr_data.segments_length_total, " ",
  --   "rsl ", rsl_data.segments_length_total, " ",
  --   "lsr ", lsr_data.segments_length_total, " ",
  --   "lrl ", lrl_data.segments_length_total, " ",
  --   "rlr ", rlr_data.segments_length_total, " "
  -- )
  local shortest_length = math.huge
  local shortest_word = ""

  if lsl_data.segments_length_total < shortest_length then
    shortest_length = lsl_data.segments_length_total
    shortest_word = "lsl"
  end
  if rsr_data.segments_length_total < shortest_length then
    shortest_length = rsr_data.segments_length_total
    shortest_word = "rsr"
  end
  if lsr_data.segments_length_total < shortest_length then
    shortest_length = lsr_data.segments_length_total
    shortest_word = "lsr"
  end
  if rsl_data.segments_length_total < shortest_length then
    shortest_length = rsl_data.segments_length_total
    shortest_word = "rsr"
  end
  if rlr_data.segments_length_total < shortest_length then
    shortest_length = rlr_data.segments_length_total
    shortest_word = "rlr"
  end
  if lrl_data.segments_length_total < shortest_length then
    shortest_length = lrl_data.segments_length_total
    shortest_word = "lrl"
  end

  --shortest_word = "lrl"

  if shortest_word == "lsl" then
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

    love.graphics.arc(
      "line",
      "open",
      origin.left_center.x,
      origin.left_center.y,
      turning_radius,
      draw_start,
      draw_finish
    )

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
  elseif shortest_word == "rsr" then
    love.graphics.line(rsr_data.leave_point.x, rsr_data.leave_point.y, rsr_data.entry_point.x, rsr_data.entry_point.y)
    -- If the starting angle is numerically bigger than the final angle, the arc is drawn counter clockwise.
    -- If the final angle is numerically bigger than the starting angle, the arc is drawn clockwise.
    local draw_start
    local draw_finish
    if rsr_data.origin_angles.start > rsr_data.origin_angles.finish then
      draw_start = rsr_data.origin_angles.start
      draw_finish = rsr_data.origin_angles.finish
    else
      draw_start = rsr_data.origin_angles.start + math.pi * 2
      draw_finish = rsr_data.origin_angles.finish
    end

    love.graphics.arc(
      "line",
      "open",
      origin.right_center.x,
      origin.right_center.y,
      turning_radius,
      draw_start,
      draw_finish
    )

    -- "end"
    if rsr_data.destination_angles.start > rsr_data.destination_angles.finish then
      draw_start = rsr_data.destination_angles.start
      draw_finish = rsr_data.destination_angles.finish
    else
      draw_start = rsr_data.destination_angles.start + math.pi * 2
      draw_finish = rsr_data.destination_angles.finish
    end

    love.graphics.arc(
      "line",
      "open",
      destination.right_center.x,
      destination.right_center.y,
      turning_radius,
      draw_start,
      draw_finish
    )
  elseif shortest_word == "lsr" then
    love.graphics.line(lsr_data.leave_point.x, lsr_data.leave_point.y, lsr_data.entry_point.x, lsr_data.entry_point.y)
    -- If the starting angle is numerically bigger than the final angle, the arc is drawn counter clockwise.
    -- If the final angle is numerically bigger than the starting angle, the arc is drawn clockwise.
    local draw_start
    local draw_finish
    if lsr_data.origin_angles.start > lsr_data.origin_angles.finish then
      draw_start = lsr_data.origin_angles.start
      draw_finish = lsr_data.origin_angles.finish + math.pi * 2
    else
      draw_start = lsr_data.origin_angles.start
      draw_finish = lsr_data.origin_angles.finish
    end

    love.graphics.arc(
      "line",
      "open",
      origin.left_center.x,
      origin.left_center.y,
      turning_radius,
      draw_start,
      draw_finish
    )

    -- "end"
    if lsr_data.destination_angles.start > lsr_data.destination_angles.finish then
      draw_start = lsr_data.destination_angles.start
      draw_finish = lsr_data.destination_angles.finish
    else
      draw_start = lsr_data.destination_angles.start + math.pi * 2
      draw_finish = lsr_data.destination_angles.finish
    end

    love.graphics.arc(
      "line",
      "open",
      destination.right_center.x,
      destination.right_center.y,
      turning_radius,
      draw_start,
      draw_finish
    )
  elseif shortest_word == "rsl" then
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

    love.graphics.line(rsl_data.leave_point.x, rsl_data.leave_point.y, rsl_data.entry_point.x, rsl_data.entry_point.y)
    -- If the starting angle is numerically bigger than the final angle, the arc is drawn counter clockwise.
    -- If the final angle is numerically bigger than the starting angle, the arc is drawn clockwise.
    local draw_start
    local draw_finish
    if rsl_data.origin_angles.start > rsl_data.origin_angles.finish then
      draw_start = rsl_data.origin_angles.start
      draw_finish = rsl_data.origin_angles.finish
    else
      draw_start = rsl_data.origin_angles.start + math.pi * 2
      draw_finish = rsl_data.origin_angles.finish
    end

    love.graphics.arc(
      "line",
      "open",
      origin.right_center.x,
      origin.right_center.y,
      turning_radius,
      draw_start,
      draw_finish
    )

    -- "end"
    if rsl_data.destination_angles.start > rsl_data.destination_angles.finish then
      draw_start = rsl_data.destination_angles.start
      draw_finish = rsl_data.destination_angles.finish + math.pi * 2
    else
      draw_start = rsl_data.destination_angles.start
      draw_finish = rsl_data.destination_angles.finish
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
  elseif shortest_word == "rlr" then
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

    -- If the starting angle is numerically bigger than the final angle, the arc is drawn counter clockwise.
    -- If the final angle is numerically bigger than the starting angle, the arc is drawn clockwise.
    local draw_start
    local draw_finish
    if rlr_data.origin_angles.start > rlr_data.origin_angles.finish then
      draw_start = rlr_data.origin_angles.start
      draw_finish = rlr_data.origin_angles.finish
    else
      draw_start = rlr_data.origin_angles.start + math.pi * 2
      draw_finish = rlr_data.origin_angles.finish
    end

    love.graphics.arc(
      "line",
      "open",
      origin.right_center.x,
      origin.right_center.y,
      turning_radius,
      draw_start,
      draw_finish
    )

    -- "end"
    if rlr_data.destination_angles.start > rlr_data.destination_angles.finish then
      draw_start = rlr_data.destination_angles.start
      draw_finish = rlr_data.destination_angles.finish
    else
      draw_start = rlr_data.destination_angles.start + math.pi * 2
      draw_finish = rlr_data.destination_angles.finish
    end

    love.graphics.arc(
      "line",
      "open",
      destination.right_center.x,
      destination.right_center.y,
      turning_radius,
      draw_start,
      draw_finish
    )

    -- "center"
    love.graphics.setColor(0, 0, 1)
    love.graphics.circle("line", rlr_data.ccc_center.center.x, rlr_data.ccc_center.center.y, turning_radius)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", rlr_data.ccc_center.center.x, rlr_data.ccc_center.center.y, 5)
    love.graphics.setColor(1, 0, 1)
    love.graphics.circle("fill", rlr_data.leave_point.x, rlr_data.leave_point.y, 5)
    love.graphics.setColor(1, 1, 0)
    love.graphics.circle("fill", rlr_data.entry_point.x, rlr_data.entry_point.y, 5)
    love.graphics.setColor(1, 1, 1)

    if rlr_data.ccc_center.angles.start > rlr_data.ccc_center.angles.finish then
      draw_start = rlr_data.ccc_center.angles.start
      draw_finish = rlr_data.ccc_center.angles.finish + math.pi * 2
    else
      draw_start = rlr_data.ccc_center.angles.start
      draw_finish = rlr_data.ccc_center.angles.finish
    end

    love.graphics.arc(
      "line",
      "open",
      rlr_data.ccc_center.center.x,
      rlr_data.ccc_center.center.y,
      turning_radius,
      draw_start,
      draw_finish
    )
  elseif shortest_word == "lrl" then
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

    -- If the starting angle is numerically bigger than the final angle, the arc is drawn counter clockwise.
    -- If the final angle is numerically bigger than the starting angle, the arc is drawn clockwise.
    local draw_start
    local draw_finish
    if lrl_data.origin_angles.start > lrl_data.origin_angles.finish then
      draw_start = lrl_data.origin_angles.start
      draw_finish = lrl_data.origin_angles.finish + math.pi * 2
    else
      draw_start = lrl_data.origin_angles.start
      draw_finish = lrl_data.origin_angles.finish
    end

    love.graphics.arc(
      "line",
      "open",
      origin.left_center.x,
      origin.left_center.y,
      turning_radius,
      draw_start,
      draw_finish
    )

    -- "end"
    if lrl_data.destination_angles.start > lrl_data.destination_angles.finish then
      draw_start = lrl_data.destination_angles.start
      draw_finish = lrl_data.destination_angles.finish + math.pi * 2
    else
      draw_start = lrl_data.destination_angles.start
      draw_finish = lrl_data.destination_angles.finish
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

    -- "center"
    love.graphics.setColor(0, 0, 1)
    love.graphics.circle("line", lrl_data.ccc_center.center.x, lrl_data.ccc_center.center.y, turning_radius)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", lrl_data.ccc_center.center.x, lrl_data.ccc_center.center.y, 5)
    love.graphics.setColor(1, 0, 1)
    love.graphics.circle("fill", lrl_data.leave_point.x, lrl_data.leave_point.y, 5)
    love.graphics.setColor(1, 1, 0)
    love.graphics.circle("fill", lrl_data.entry_point.x, lrl_data.entry_point.y, 5)
    love.graphics.setColor(1, 1, 1)

    if lrl_data.ccc_center.angles.start > lrl_data.ccc_center.angles.finish then
      draw_start = lrl_data.ccc_center.angles.start
      draw_finish = lrl_data.ccc_center.angles.finish
    else
      draw_start = lrl_data.ccc_center.angles.start + math.pi * 2
      draw_finish = lrl_data.ccc_center.angles.finish
    end

    love.graphics.arc(
      "line",
      "open",
      lrl_data.ccc_center.center.x,
      lrl_data.ccc_center.center.y,
      turning_radius,
      draw_start,
      draw_finish
    )
  end
end
