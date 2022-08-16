local Common = require "Common"
local Vehicle = require "Vehicle"
local Dubins = require "Dubins"

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

function love.load(args)
  love.window.setMode(window_width, window_height, {resizable = false})

  origin = Vehicle:new(nil, {x = window_width / 4, y = window_height / 2}, 0)
  origin.image = love.graphics.newImage("assets/truck_origin.png")

  destination = Vehicle:new(nil, {x = window_width * 3 / 4, y = window_height / 2}, 0)
  destination.image = love.graphics.newImage("assets/truck_destination.png")
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

  origin:update()
  destination:update()
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
  love.graphics.circle("line", truck.left_center.x, truck.left_center.y, truck.turning_radius)

  love.graphics.setColor(0.25, 0, 0)
  love.graphics.circle("line", truck.right_center.x, truck.right_center.y, truck.turning_radius)

  love.graphics.setColor(0.25, 0.25, 0.25)
  local start = Common.vector_add(Common.vector_mul(truck.head, 200), truck.position)
  local finish = Common.vector_add(Common.vector_mul(truck.head, -200), truck.position)
  --love.graphics.line(start.x, start.y, finish.x, finish.y)
  lineStipple(start.x, start.y, finish.x, finish.y)

  love.graphics.setColor(1, 1, 1)
end

local function get_dimmed_colour(colour_)
  local dimming_constant = 0.45
  return {colour_[1] * dimming_constant, colour_[2] * dimming_constant, colour_[3] * dimming_constant}
end

local function draw_lsl(lsl_data, colour_)
  local sr, sg, sb, sa = love.graphics.getColor()

  love.graphics.setColor(colour_)

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
    origin.turning_radius,
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
    destination.turning_radius,
    draw_start,
    draw_finish
  )

  love.graphics.setColor(sr, sg, sb, sa)
end

local function draw_rsr(rsr_data, colour_)
  local sr, sg, sb, sa = love.graphics.getColor()

  love.graphics.setColor(colour_)
  love.graphics.line(rsr_data.leave_point.x, rsr_data.leave_point.y, rsr_data.entry_point.x, rsr_data.entry_point.y)
  -- If the starting angle is numerically bigger than the final angle, the arc is drawn counter clockwise.
  -- If the final angle is numerically bigger than the starting angle, the arc is drawn clockwise.
  local draw_start
  local draw_finish
  if rsr_data.origin_angles.start > rsr_data.origin_angles.finish then
    draw_start = rsr_data.origin_angles.finish + math.pi * 2
    draw_finish = rsr_data.origin_angles.start
  else
    draw_start = rsr_data.origin_angles.finish
    draw_finish = rsr_data.origin_angles.start
  end

  love.graphics.arc(
    "line",
    "open",
    origin.right_center.x,
    origin.right_center.y,
    origin.turning_radius,
    draw_start,
    draw_finish
  )

  -- "end"
  if rsr_data.destination_angles.start > rsr_data.destination_angles.finish then
    draw_start = rsr_data.destination_angles.start
    draw_finish = rsr_data.destination_angles.finish + math.pi * 2
  else
    draw_start = rsr_data.destination_angles.start
    draw_finish = rsr_data.destination_angles.finish
  end

  love.graphics.arc(
    "line",
    "open",
    destination.right_center.x,
    destination.right_center.y,
    destination.turning_radius,
    draw_start,
    draw_finish
  )

  love.graphics.setColor(sr, sg, sb, sa)
end

local function draw_rsl(rsl_data, colour_)
  local sr, sg, sb, sa = love.graphics.getColor()

  love.graphics.setColor(colour_)
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
    origin.turning_radius,
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
    destination.turning_radius,
    draw_start,
    draw_finish
  )

  love.graphics.setColor(sr, sg, sb, sa)
end

local function draw_lsr(lsr_data, colour_)
  local sr, sg, sb, sa = love.graphics.getColor()

  love.graphics.setColor(colour_)
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
    origin.turning_radius,
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
    destination.turning_radius,
    draw_start,
    draw_finish
  )

  love.graphics.setColor(sr, sg, sb, sa)
end

local function draw_lrl(lrl_data, colour_)
  local sr, sg, sb, sa = love.graphics.getColor()

  love.graphics.setColor(colour_)
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
    origin.turning_radius,
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
    destination.turning_radius,
    draw_start,
    draw_finish
  )

  -- "center"
  -- love.graphics.setColor(0, 0, 1)
  -- love.graphics.circle("line", lrl_data.ccc_center.center.x, lrl_data.ccc_center.center.y, turning_radius)
  -- love.graphics.setColor(1, 1, 1)
  -- love.graphics.circle("fill", lrl_data.ccc_center.center.x, lrl_data.ccc_center.center.y, 5)
  -- love.graphics.setColor(1, 0, 1)
  -- love.graphics.circle("fill", lrl_data.leave_point.x, lrl_data.leave_point.y, 5)
  -- love.graphics.setColor(1, 1, 0)
  -- love.graphics.circle("fill", lrl_data.entry_point.x, lrl_data.entry_point.y, 5)
  -- love.graphics.setColor(1, 1, 1)

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
    origin.turning_radius,
    draw_start,
    draw_finish
  )

  love.graphics.setColor(sr, sg, sb, sa)
end

local function draw_rlr(rlr_data, colour_)
  local sr, sg, sb, sa = love.graphics.getColor()

  love.graphics.setColor(colour_)
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
    origin.turning_radius,
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
    destination.turning_radius,
    draw_start,
    draw_finish
  )

  -- "center"
  -- love.graphics.setColor(0, 0, 1)
  -- love.graphics.circle("line", rlr_data.ccc_center.center.x, rlr_data.ccc_center.center.y, turning_radius)
  -- love.graphics.setColor(1, 1, 1)
  -- love.graphics.circle("fill", rlr_data.ccc_center.center.x, rlr_data.ccc_center.center.y, 5)
  -- love.graphics.setColor(1, 0, 1)
  -- love.graphics.circle("fill", rlr_data.leave_point.x, rlr_data.leave_point.y, 5)
  -- love.graphics.setColor(1, 1, 0)
  -- love.graphics.circle("fill", rlr_data.entry_point.x, rlr_data.entry_point.y, 5)
  -- love.graphics.setColor(1, 1, 1)

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
    origin.turning_radius,
    draw_start,
    draw_finish
  )

  love.graphics.setColor(sr, sg, sb, sa)
end

function love.draw()

  draw_one(origin, {r = 1, g = 1, b = 0})
  draw_one(destination, {r = 0, g = 0, b = 1})

  local lsl_evaluate = true
  local rsr_evaluate = true
  local rsl_evaluate = true
  local lsr_evaluate = true
  local lrl_evaluate = false
  local rlr_evaluate = false

  local lsl_data = Dubins.LSL(origin, destination)
  local rsr_data = Dubins.RSR(origin, destination)
  local rsl_data = Dubins.RSL(origin, destination)
  local lsr_data = Dubins.LSR(origin, destination)
  local lrl_data = Dubins.LRL(origin, destination)
  local rlr_data = Dubins.RLR(origin, destination)

  local lsl_colour = {0, 1, 1}
  local rsr_colour = {1, 0, 0}
  local rsl_colour = {0, 1, 0}
  local lsr_colour = {1, 0, 1}
  local lrl_colour = {0, 0, 1}
  local rlr_colour = {1, 1, 0}

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

  if lsl_evaluate and lsl_data.segments_length_total < shortest_length then
    shortest_length = lsl_data.segments_length_total
    shortest_word = "lsl"
  end
  if rsr_evaluate and rsr_data.segments_length_total < shortest_length then
    shortest_length = rsr_data.segments_length_total
    shortest_word = "rsr"
  end
  if lsr_evaluate and lsr_data.segments_length_total < shortest_length then
    shortest_length = lsr_data.segments_length_total
    shortest_word = "lsr"
  end
  if rsl_evaluate and rsl_data.segments_length_total < shortest_length then
    shortest_length = rsl_data.segments_length_total
    shortest_word = "rsl"
  end
  if rlr_evaluate and rlr_data.segments_length_total < shortest_length then
    shortest_length = rlr_data.segments_length_total
    shortest_word = "rlr"
  end
  if lrl_evaluate and lrl_data.segments_length_total < shortest_length then
    --shortest_length = lrl_data.segments_length_total
    shortest_word = "lrl"
  end

  --print("shortest_word", shortest_word)

  if lsl_evaluate and shortest_word ~= "lsl" then
    draw_lsl(lsl_data, get_dimmed_colour(lsl_colour))
  end
  if rsr_evaluate and shortest_word ~= "rsr" then
    draw_rsr(rsr_data, get_dimmed_colour(rsr_colour))
  end
  if lsr_evaluate and shortest_word ~= "lsr" then
    draw_lsr(lsr_data, get_dimmed_colour(lsr_colour))
  end
  if rsl_evaluate and shortest_word ~= "rsl" then
    draw_rsl(rsl_data, get_dimmed_colour(rsl_colour))
  end
  if rlr_evaluate and shortest_word ~= "rlr" then
    draw_rlr(rlr_data, get_dimmed_colour(rlr_colour))
  end
  if lrl_evaluate and shortest_word ~= "lrl" then
    draw_lrl(lrl_data, get_dimmed_colour(lrl_colour))
  end

  if lsl_evaluate and shortest_word == "lsl" then
    draw_lsl(lsl_data, lsl_colour)
  elseif rsr_evaluate and shortest_word == "rsr" then
    draw_rsr(rsr_data, rsr_colour)
  elseif lsr_evaluate and shortest_word == "lsr" then
    draw_lsr(lsr_data, lsr_colour)
  elseif rsl_evaluate and shortest_word == "rsl" then
    draw_rsl(rsl_data, rsl_colour)
  elseif rlr_evaluate and shortest_word == "rlr" then
    draw_rlr(rlr_data, rlr_colour)
  elseif lrl_evaluate and shortest_word == "lrl" then
    draw_lrl(lrl_data, lrl_colour)
  end
end
