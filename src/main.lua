local Common = require "Common"
local Vehicle = require "Vehicle"
local VehicleData = require "VehicleData"
local Planning = require "Planning"
local Vector2 = require "Vector2"

-- luacheck: globals love

--local test = require "test"

io.stdout:setvbuf("no") -- This makes is so that print() statements print right away.

local SCALE = 20.0
local GFX_SCALE = 20 -- screenshot scale: 20

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
local vehicle_data = {}

local window_width, window_height = 768, 768 -- screenshot sizes: 768, 768
local scale_start_location = true

local _WHAT_TO_TEST__TEST_NEW = "test-new"
local _WHAT_TO_TEST__TEST_OLD = "test-old"
local _WHAT_TO_TEST__STRAIGHT_LEFT = "straight-left"
local _what_to_test = _WHAT_TO_TEST__STRAIGHT_LEFT

local _should_recompute_data = true
local _computed_data = {is_freshly_computed = true}
local _run_timer = 0.0

local _direction = Planning.FORWARD
local _direction_switch_accumulator = -math.huge

local function disp_y(y_)
  return window_height - y_
end

local function sc_x(x_)
  return GFX_SCALE * x_
end
local function sc_y(y_)
  return GFX_SCALE * y_
end

function love.load(args)
  vehicle_data = VehicleData:new()

  love.window.setMode(window_width, window_height, {resizable = false})

  if not scale_start_location then
    origin = Vehicle:new(nil, Vector2(28, 15), 0)
    destination = Vehicle:new(nil, Vector2(12, 15), 0)
  else
    local fourth_w = (window_width / 4) / GFX_SCALE
    local half_h = (window_height / 2) / GFX_SCALE

    origin = Vehicle:new(nil, Vector2(fourth_w * 1, half_h), 0)
    destination = Vehicle:new(nil, Vector2(fourth_w * 3, half_h), 0)
  end

  origin.image = love.graphics.newImage("assets/truck_origin.png")
  destination.image = love.graphics.newImage("assets/truck_destination.png")
end

local function compute_data()
  _computed_data.is_freshly_computed = true

  if _what_to_test == _WHAT_TO_TEST__STRAIGHT_LEFT then
    _computed_data.check_data = Planning.Straight_Curve(origin, destination, vehicle_data, Planning.LEFT, _direction)
  elseif _what_to_test == _WHAT_TO_TEST__TEST_NEW then
    _computed_data = {best_data = {}}
    local best_data = nil
    local shortest_length = math.huge

    for i = 0, 10, 1 do
      local ii = i / 10
      ii = math.max(0.05, ii)

      for j = 0, 10, 1 do
        local jj = j / 10
        jj = math.max(0.05, jj)
        local new_lsl =
          Planning.ComputePath(
          origin,
          destination,
          vehicle_data,
          Planning.START_STOPPED,
          Planning.LEFT,
          Planning.LEFT,
          ii,
          jj,
          _direction
        )
        local new_rsr =
          Planning.ComputePath(
          origin,
          destination,
          vehicle_data,
          Planning.START_STOPPED,
          Planning.RIGHT,
          Planning.RIGHT,
          ii,
          jj,
          _direction
        )
        local new_rsl =
          Planning.ComputePath(
          origin,
          destination,
          vehicle_data,
          Planning.START_STOPPED,
          Planning.RIGHT,
          Planning.LEFT,
          ii,
          jj,
          _direction
        )
        local new_lsr =
          Planning.ComputePath(
          origin,
          destination,
          vehicle_data,
          Planning.START_STOPPED,
          Planning.LEFT,
          Planning.RIGHT,
          ii,
          jj,
          _direction
        )

        if new_lsl.segments_length_total < shortest_length then
          shortest_length = new_lsl.segments_length_total
          best_data = new_lsl
        end
        if new_rsr.segments_length_total < shortest_length then
          shortest_length = new_rsr.segments_length_total
          best_data = new_rsr
        end
        if new_rsl.segments_length_total < shortest_length then
          shortest_length = new_rsl.segments_length_total
          best_data = new_rsl
        end
        if new_lsr.segments_length_total < shortest_length then
          shortest_length = new_lsr.segments_length_total
          best_data = new_lsr
        end
      end
    end

    _computed_data.best_data = best_data
  elseif _what_to_test == _WHAT_TO_TEST__TEST_OLD then
    -- This part of the "if" is there to test specific parameters of the algorithm.
    local lsl_evaluate = true
    local rsr_evaluate = true
    local rsl_evaluate = true
    local lsr_evaluate = true

    _computed_data.lsl_data = nil
    _computed_data.rsr_data = nil
    _computed_data.rsl_data = nil
    _computed_data.lsr_data = nil

    -- print("cycle_value", cycle_value)
    if lsl_evaluate then
      _computed_data.lsl_data =
        Planning.ComputePath(
        origin,
        destination,
        vehicle_data,
        Planning.START_MOVING,
        Planning.LEFT,
        Planning.LEFT,
        nil,
        1,
        1,
        _direction
      )
    end
    if rsr_evaluate then
      _computed_data.rsr_data =
        Planning.ComputePath(
        origin,
        destination,
        vehicle_data,
        Planning.START_MOVING,
        Planning.RIGHT,
        Planning.RIGHT,
        nil,
        1,
        1,
        _direction
      )
    end
    if rsl_evaluate then
      _computed_data.rsl_data =
        Planning.ComputePath(
        origin,
        destination,
        vehicle_data,
        Planning.START_STOPPED,
        Planning.RIGHT,
        Planning.LEFT,
        nil,
        1,
        1,
        _direction
      )
    end
    if lsr_evaluate then
      _computed_data.lsr_data =
        Planning.ComputePath(
        origin,
        destination,
        vehicle_data,
        Planning.START_STOPPED,
        Planning.LEFT,
        Planning.RIGHT,
        nil,
        1,
        1,
        _direction
      )
    end

    -- require "pl/pretty".dump(lsl_data)

    local shortest_length = math.huge
    _computed_data.shortest_word = ""

    if lsl_evaluate and _computed_data.lsl_data.segments_length_total < shortest_length then
      shortest_length = _computed_data.lsl_data.segments_length_total
      _computed_data.shortest_word = "lsl"
    end
    if rsr_evaluate and _computed_data.rsr_data.segments_length_total < shortest_length then
      shortest_length = _computed_data.rsr_data.segments_length_total
      _computed_data.shortest_word = "rsr"
    end
    if lsr_evaluate and _computed_data.lsr_data.segments_length_total < shortest_length then
      shortest_length = _computed_data.lsr_data.segments_length_total
      _computed_data.shortest_word = "lsr"
    end
    if rsl_evaluate and _computed_data.rsl_data.segments_length_total < shortest_length then
      -- shortest_length = rsl_data.segments_length_total
      _computed_data.shortest_word = "rsl"
    end

  --print("shortest_word", shortest_word)
  end
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

function love.update(dt_)
  _run_timer = _run_timer + dt_

  local previous_vehicle_selected = KeyboardState.selected

  update_keyboard_state()

  if previous_vehicle_selected ~= KeyboardState.selected then
    _should_recompute_data = true
  end

  local updateable
  if KeyboardState.selected == "origin" then
    updateable = origin
  else
    updateable = destination
  end

  if KeyboardState.move_down then
    updateable.position.y = updateable.position.y - 1 / GFX_SCALE
    _should_recompute_data = true
  end
  if KeyboardState.move_up then
    updateable.position.y = updateable.position.y + 1 / GFX_SCALE
    _should_recompute_data = true
  end
  if KeyboardState.move_left then
    updateable.position.x = updateable.position.x - 1 / GFX_SCALE
    _should_recompute_data = true
  end
  if KeyboardState.move_right then
    updateable.position.x = updateable.position.x + 1 / GFX_SCALE
    _should_recompute_data = true
  end
  if KeyboardState.rotate_cw then
    updateable.orientation = updateable.orientation + (math.pi / 256)
    _should_recompute_data = true
  end
  if KeyboardState.rotate_ccw then
    updateable.orientation = updateable.orientation - (math.pi / 256)
    _should_recompute_data = true
  end

  updateable.orientation = Common.over_2pi(updateable.orientation)

  origin:update()
  destination:update()

  _direction_switch_accumulator = _direction_switch_accumulator + dt_
  if _direction_switch_accumulator >= 2 then
    _direction_switch_accumulator = _direction_switch_accumulator - 2
    if _direction == Planning.FORWARD then
      _direction = Planning.REVERSE
    else
      _direction = Planning.FORWARD
    end

    _should_recompute_data = true
    print("_direction", _direction)
  end

  if _should_recompute_data then
    compute_data()
    _should_recompute_data = false
  else
    _computed_data.is_freshly_computed = false
  end
end

function love.keyreleased(key)
  if key == "escape" then
    love.event.quit()
  end
end

-- luacheck: ignore lineStipple
-- https://love2d.org/wiki/LineStippleSnippet
local function lineStipple(x1, y1, x2, y2, dash_, gap_)
  local dash = dash_ or 10
  local gap = dash + (gap_ or 10)

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
        love.graphics.line(sc_x(lastA), disp_y(sc_y(lastB)), sc_x(a), disp_y(sc_y(b)))
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

--[[
  Convenient function to draw an adapted-to-our-graphics-setup circle at position_ with a radius of radius_; setting the
  third parameter to "fill" will draw a filled circle, otherwise the circle will be drawn as a line.
]]
local function draw_circle(position_, radius_, filled_)
  local style = filled_ or "line"
  if position_.x then
    love.graphics.circle(style, sc_x(position_.x), disp_y(sc_y(position_.y)), sc_x(radius_))
  else
    love.graphics.circle(style, sc_x(position_.position.x), disp_y(sc_y(position_.position.y)), sc_x(radius_))
  end
end

local function draw_one(truck, colour)
  -- love.graphics.setColor(1, 0, 0)
  -- draw_circle(truck.position, 3/GFX_SCALE, "fill")
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(
    truck.image,
    sc_x(truck.position.x),
    disp_y(sc_y(truck.position.y)),
    -truck.orientation,
    1,
    1,
    sprite.pivot.x,
    sprite.pivot.y
  )
end

local function draw_gizmo(vector_, force_colour_)
  local sr, sg, sb, sa = love.graphics.getColor()

  local colour = force_colour_ or {0.8, 0.8, 0.8}

  local arrow_end = (vector_.position * GFX_SCALE) + Vector2(2 * SCALE, 0):rotate_copy(vector_.orientation)

  love.graphics.setColor(colour)
  love.graphics.circle("fill", sc_x(vector_.position.x), disp_y(sc_y(vector_.position.y)), 3)
  love.graphics.line(sc_x(vector_.position.x), disp_y(sc_y(vector_.position.y)), arrow_end.x, disp_y(arrow_end.y))

  love.graphics.setColor(sr, sg, sb, sa)
end

local function get_dimmed_colour(colour_)
  local dimming_constant = 0.45
  return {colour_[1] * dimming_constant, colour_[2] * dimming_constant, colour_[3] * dimming_constant}
end

--[[
  Notes from https://love2d.org/wiki/love.graphics.arc:
  The arc is drawn counter clockwise if the starting angle is numerically bigger than the final angle. The arc is drawn
  clockwise if the final angle is numerically bigger than the starting angle.
]]
local function adjust_arc_start_finish(start_, finish_, dir_)
  -- Because we're drawing upside down, we flip the angles
  start_ = Common.clean_angle_over_2pi(-start_)
  finish_ = Common.clean_angle_over_2pi(-finish_)

  local ret_start = start_
  local ret_finish = finish_

  if dir_ == Planning.CCW then
    if start_ >= finish_ then
      -- If the starting angle is numerically bigger than the final angle, the arc is drawn counter clockwise.
      ret_start = start_
      ret_finish = finish_
    else -- start_ < finish_ then
      -- If the final angle is numerically bigger than the starting angle, the arc is drawn clockwise.
      ret_start = start_ + math.pi * 2
      ret_finish = finish_
    end
  elseif dir_ == Planning.CW then
    if start_ >= finish_ then
      -- If the starting angle is numerically bigger than the final angle, the arc is drawn counter clockwise.
      ret_start = start_
      ret_finish = finish_ + math.pi * 2
    else -- start_ < finish_ then
      -- If the final angle is numerically bigger than the starting angle, the arc is drawn clockwise.
      ret_start = start_
      ret_finish = finish_
    end
  end

  return ret_start, ret_finish
end

--[[
  Convenient function to draw an adapted-to-our-graphics-setup line segment between vec1_ and vec2_.
]]
local function draw_segment(vec1_, vec2_)
  if vec1_.x and vec1_.y and vec2_.x and vec2_.y then
    love.graphics.line(sc_x(vec1_.x), disp_y(sc_y(vec1_.y)), sc_x(vec2_.x), disp_y(sc_y(vec2_.y)))
    return
  end

  if vec1_.position and vec2_.position then
    draw_segment(vec1_.position, vec2_.position)
    return
  end
  if vec1_.position then
    draw_segment(vec1_.position, vec2_)
    return
  end
  if vec2_.position then
    draw_segment(vec1_, vec2_.position)
    return
  end
  print("???")
  print("vec1_")
  require "pl/pretty".dump(vec1_)
  print("vec2_")
  require "pl/pretty".dump(vec2_)
end

--[[
  Convenient function to draw an adapted-to-our-graphics-setup line that goes through line_.
]]
local function draw_line(line_)
  local p1 = Vector2(-1000, Common.line_get_y(line_, -1000))
  local p2 = Vector2(1000, Common.line_get_y(line_, 1000))
  draw_segment(p1, p2)
end

--[[
  Convenient function to draw an adapted-to-our-graphics-setup text (text_) along with a dot where it start (position_).
]]
local function draw_label(text_, position_)
  local sr, sg, sb, sa = love.graphics.getColor()

  love.graphics.setColor(0, 0, 0)
  love.graphics.circle("fill", sc_x(position_.x), disp_y(sc_y(position_.y)), 3)
  love.graphics.print(text_, sc_x(position_.x), disp_y(sc_y(position_.y)))

  love.graphics.setColor(sr, sg, sb, sa)
end

local function draw_straight_curve(data_, colour_)
  local sr, sg, sb, sa = love.graphics.getColor()

  local alt_colour = {colour_[1] * 0.5, colour_[2] * 0.5, colour_[3] * 0.5}

  if not _start_time then
    _start_time = 0
  end

  if _computed_data.is_freshly_computed then
    _start_time = _run_timer
  end

  local time_since_timer_start = _run_timer - _start_time
  time_since_timer_start = math.floor(time_since_timer_start)

  local test_run_to_display_index = 1 + time_since_timer_start % #data_.test_runs

  --print("#data_.test_runs", #data_.test_runs, "test_run_to_display_index", test_run_to_display_index)

  local test_run_to_display = data_.test_runs[test_run_to_display_index]

  --require "pl/pretty".dump(test_run_to_display)

  local do_draw_test_run = function(test_run_)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("test:run #" .. test_run_to_display_index, 0, 0)
    love.graphics.setColor(0.85, 0.85, 0.85)
    draw_line(data_.input.line_origin)
    -- current_run.curve_out_out
    -- current_run.curve_out_center
    -- current_run.tentative_curve_out_in
    -- current_run.tentative_straight_out

    love.graphics.setColor(1, 0, 0)
    draw_circle(test_run_.curve_out_center, 3 / GFX_SCALE, "fill")

    love.graphics.setColor(alt_colour)
    draw_segment(data_.input.destination_.position, test_run_.curve_out_out.position)
    love.graphics.setColor(alt_colour)
    draw_segment(test_run_.tentative_curve_out_in.position, test_run_.tentative_straight_out.position)

    draw_gizmo(test_run_.tentative_straight_out)
  end

  local do_draw = function()
    -- draw_segment(data_.curve_out_center, data_.straight_out.position)
    -- draw_segment(data_.curve_out_center, data_.curve_out_in.position)

    -- curve_out lines
    love.graphics.setColor(alt_colour)
    if data_.curve_out_out then
      draw_segment(data_.input.destination_.position, data_.curve_out_out.position)
    end

    love.graphics.setColor(alt_colour)
    if data_.curve_out_in and data_.straight_out then
      draw_segment(data_.curve_out_in.position, data_.straight_out.position)
    end

    -- -- straight
    love.graphics.setColor(colour_)
    if data_.straight_out then
      draw_segment(data_.input.origin_.position, data_.straight_out.position)
    end

    love.graphics.setColor(1, 0, 0)
    if data_.curve_out_center then
      draw_circle(data_.curve_out_center, 3 / GFX_SCALE, "fill")
    end
    -- love.graphics.setColor(0, 1, 0)
    -- --draw_circle(data_.curve_out_in_center, 3 / GFX_SCALE, "fill")

    -- draw_gizmo(data_.curve_out_out)
    -- draw_gizmo(data_.curve_out_in)

    -- "end"

    if data_.curve_out_angles and data_.curve_out_center then
      if data_.curve_out_angles.start ~= math.huge and data_.curve_out_angles.finish ~= math.huge then
        local draw_start, draw_finish =
          adjust_arc_start_finish(
          data_.curve_out_angles.start,
          data_.curve_out_angles.finish,
          data_.input.turning_direction_out_ * _direction
        )

        love.graphics.arc(
          "line",
          "open",
          sc_x(data_.curve_out_center.x),
          disp_y(sc_y(data_.curve_out_center.y)),
          GFX_SCALE * data_.res_out.curve_radius,
          draw_start,
          draw_finish
        )
      end
    end
  end

  --do_draw_test_run(test_run_to_display)
  do_draw()
  -- _, _ = pcall(do_draw) -- We don't want that a missing variable interupts the execution.

  love.graphics.setColor(sr, sg, sb, sa)
end

local function draw_curve(data_, colour_)
  -- if data_.segments_length_total == math.huge then
  --   return
  -- end
  local sr, sg, sb, sa = love.graphics.getColor()

  local alt_colour = {colour_[1] * 0.5, colour_[2] * 0.5, colour_[3] * 0.5}

  local colour_actual_radius = {0.5, 0, 0}
  local colour_expanded_radius = {0, 0.5, 0}
  local colour_debug_thing = {0, 0, 1}

  local do_draw = function()
    -- curve_in lines
    love.graphics.setColor(alt_colour)
    love.graphics.line(
      sc_x(data_.input.origin_.position.x),
      disp_y(sc_y(data_.input.origin_.position.y)),
      sc_x(data_.curve_in_in.position.x),
      disp_y(sc_y(data_.curve_in_in.position.y))
    )

    love.graphics.setColor(alt_colour)
    love.graphics.line(
      sc_x(data_.curve_in_out.position.x),
      disp_y(sc_y(data_.curve_in_out.position.y)),
      sc_x(data_.straight_in.position.x),
      disp_y(sc_y(data_.straight_in.position.y))
    )

    -- curve_out lines
    love.graphics.setColor(alt_colour)
    love.graphics.line(
      sc_x(data_.input.destination_.position.x),
      disp_y(sc_y(data_.input.destination_.position.y)),
      sc_x(data_.curve_out_out.position.x),
      disp_y(sc_y(data_.curve_out_out.position.y))
    )

    love.graphics.setColor(alt_colour)
    love.graphics.line(
      sc_x(data_.curve_out_in.position.x),
      disp_y(sc_y(data_.curve_out_in.position.y)),
      sc_x(data_.straight_out.position.x),
      disp_y(sc_y(data_.straight_out.position.y))
    )

    -- straight
    love.graphics.setColor(colour_)
    love.graphics.line(
      sc_x(data_.straight_in.position.x),
      disp_y(sc_y(data_.straight_in.position.y)),
      sc_x(data_.straight_out.position.x),
      disp_y(sc_y(data_.straight_out.position.y))
    )

    love.graphics.setColor(colour_)

    -- If the starting angle is numerically bigger than the final angle, the arc is drawn counter clockwise.
    -- If the final angle is numerically bigger than the starting angle, the arc is drawn clockwise.
    if data_.curve_in_angles.start ~= math.huge and data_.curve_in_angles.finish ~= math.huge then
      local draw_start, draw_finish =
        adjust_arc_start_finish(
        data_.curve_in_angles.start,
        data_.curve_in_angles.finish,
        data_.input.turning_direction_in_ * _direction
      )

      love.graphics.arc(
        "line",
        "open",
        sc_x(data_.curve_in_center.x),
        disp_y(sc_y(data_.curve_in_center.y)),
        GFX_SCALE * data_.input.curve_in_radius_,
        draw_start,
        draw_finish
      )
    end

    -- "end"

    if data_.curve_out_angles.start ~= math.huge and data_.curve_out_angles.finish ~= math.huge then
      local draw_start, draw_finish =
        adjust_arc_start_finish(
        data_.curve_out_angles.start,
        data_.curve_out_angles.finish,
        data_.input.turning_direction_out_ * _direction
      )

      love.graphics.arc(
        "line",
        "open",
        sc_x(data_.curve_out_center.x),
        disp_y(sc_y(data_.curve_out_center.y)),
        GFX_SCALE * data_.input.curve_out_radius_,
        draw_start,
        draw_finish
      )
    end

    love.graphics.setColor(0, 0, 0)
    love.graphics.print("path length: " .. string.format("%.2f", data_.segments_length_total), 5, 5)
    ---------------

    -- love.graphics.setColor(colour_actual_radius)
    -- draw_circle(data_.curve_in_center, data_.input.curve_in_radius_)
    -- draw_circle(data_.curve_in_center, 3 / GFX_SCALE, "fill")
    -- draw_circle(data_.curve_out_center, data_.input.curve_out_radius_)
    -- draw_circle(data_.curve_out_center, 3 / GFX_SCALE, "fill")

    -- love.graphics.setColor(0, 1, 0)
    -- draw_circle(data_.curve_in_center, data_.cier)

    -- love.graphics.setColor(1, 0, 1)
    -- draw_circle(data_.curve_in_center, data_.tangent_i_r)

    -- love.graphics.setColor(colour_debug_thing)
    -- draw_segment(data_.input.origin_, data_.curve_in_in)
    -- draw_segment(data_.a_point_on_cic_si_circle, data_.curve_in_in)
    -- draw_segment(data_.a_point_on_cic_si_circle, data_.curve_in_center)

    -- draw_segment(data_.tangent_i_p, data_.curve_in_center)
    -- draw_line(data_.a_point_on_cic_si_circle_line)

    -- draw_label("curve_in_in", data_.curve_in_in.position)
    -- -- draw_label("a_point_on_cic_si_circle", data_.a_point_on_cic_si_circle.position)
    -- draw_label("tangent_i_p", data_.tangent_i_p)

    ---------

    -- -- curve_in-circle
    -- love.graphics.setColor(colour_actual_radius)
    -- draw_circle(data_.curve_in_center, data_.input.curve_in_radius_)

    -- -- curve_in_in
    -- love.graphics.setColor(colour_debug_thing)
    -- draw_segment(data_.input.origin_, data_.curve_in_in)

    -- -- curve_in_center
    -- love.graphics.setColor(colour_debug_thing)
    -- draw_circle(data_.curve_in_center, 3/GFX_SCALE, "fill")

    -- -- curve_out-center
    -- love.graphics.setColor(colour_debug_thing)
    -- draw_circle(data_.curve_out_center, 3/GFX_SCALE, "fill")
    -- love.graphics.setColor(colour_actual_radius)
    -- draw_circle(data_.curve_out_center, data_.input.curve_out_radius_)

    -- -- curve_out_out
    -- love.graphics.setColor(colour_debug_thing)
    -- draw_segment(data_.curve_out_out, data_.input.destination_)

    -- -- a_point_on_cic_si_circle
    -- love.graphics.setColor(1, 0, 0)
    -- draw_segment(data_.curve_in_in, data_.a_point_on_cic_si_circle)

    -- -- a_point_on_coc_so_circle
    -- love.graphics.setColor(1, 0, 0)
    -- draw_segment(data_.curve_out_out, data_.a_point_on_coc_so_circle)

    -- -- tangents
    -- love.graphics.setColor(1, 0, 1)
    -- draw_circle(data_.curve_in_center, data_.tangent_i_r)
    -- draw_circle(data_.curve_out_center, data_.tangent_o_r)
    -- love.graphics.setColor(0, 1, 0)
    -- draw_line(data_.a_point_on_cic_si_circle_line)
    -- draw_line(data_.a_point_on_coc_so_circle_line)
    -- draw_segment(data_.ci_intersect, data_.co_intersect)

    -- -- curve_in_exit_radius_s
    -- love.graphics.setColor(0, 0, 0)
    -- draw_segment(data_.curve_in_center, data_.tangent_i_p)
    -- draw_segment(data_.curve_in_center, data_.a_point_on_cic_si_circle)
    -- love.graphics.setColor(1, 0, 0)
    -- draw_segment(data_.tangent_i_p, data_.a_point_on_cic_si_circle)
  end

  -- love.graphics.setColor(colour_actual_radius)
  -- draw_circle(data_.curve_in_center, data_.input.curve_in_radius_)
  -- draw_circle(data_.curve_in_center, 3 / GFX_SCALE, "fill")
  -- draw_circle(data_.curve_out_center, data_.input.curve_out_radius_)
  -- draw_circle(data_.curve_out_center, 3 / GFX_SCALE, "fill")

  -- love.graphics.setColor(0, 1, 0)
  -- draw_circle(data_.curve_in_center, data_.curve_in_exit_radius)
  -- draw_circle(data_.curve_out_center, data_.curve_out_enter_radius)

  -- love.graphics.setColor(1, 0, 1)
  -- draw_circle(data_.curve_in_center, data_.tangent_i_r)
  -- draw_circle(data_.curve_out_center, data_.tangent_o_r)

  -- love.graphics.setColor(colour_debug_thing)
  -- draw_segment(data_.input.origin_, data_.curve_in_in)
  -- draw_segment(data_.a_point_on_cic_si_circle.position, data_.curve_in_in.position)
  -- draw_segment(data_.a_point_on_cic_si_circle.position, data_.curve_in_center)

  -- draw_segment(data_.input.destination_, data_.curve_out_out)
  -- draw_segment(data_.a_point_on_coc_so_circle.position, data_.curve_out_out.position)
  -- draw_segment(data_.a_point_on_coc_so_circle.position, data_.curve_out_center)

  -- draw_segment(data_.tangent_i_p, data_.curve_in_center)
  -- draw_line(data_.a_point_on_cic_si_circle_line)

  -- love.graphics.setColor(1, 1, 0)
  -- draw_circle(data_.a_point_on_cic_si_circle, 3 / GFX_SCALE, "fill")

  -- draw_label("curve_in_in", data_.curve_in_in.position)
  -- -- draw_label("a_point_on_cic_si_circle", data_.a_point_on_cic_si_circle.position)
  -- draw_label("tangent_i_p", data_.tangent_i_p)

  --do_draw()
  -- luacheck: push ignore _
  _, _ = pcall(do_draw) -- We don't want that a missing variable interupts the execution.
  -- luacheck: pop

  love.graphics.setColor(sr, sg, sb, sa)
end

function love.draw()
  love.graphics.setBackgroundColor(1, 1, 1)
  draw_one(origin, {r = 1, g = 1, b = 0})
  draw_one(destination, {r = 0, g = 0, b = 1})

  if _what_to_test == _WHAT_TO_TEST__STRAIGHT_LEFT then
    if _computed_data.check_data then
      local colour = {0, 1, 1}
      draw_straight_curve(_computed_data.check_data, colour)
    end
  elseif _what_to_test == _WHAT_TO_TEST__TEST_NEW then
    if _computed_data.best_data then
      local colour = {0, 1, 1}
      draw_curve(_computed_data.best_data, colour)
    end
  elseif _what_to_test == _WHAT_TO_TEST__TEST_OLD then
    local lsl_colour = {0, 1, 1}
    local rsr_colour = {1, 0, 0}
    local rsl_colour = {0, 1, 0}
    local lsr_colour = {1, 0, 1}

    if _computed_data.lsl_data and _computed_data.shortest_word ~= "lsl" then
      draw_curve(_computed_data.lsl_data, get_dimmed_colour(lsl_colour))
    end
    if _computed_data.rsr_data and _computed_data.shortest_word ~= "rsr" then
      draw_curve(_computed_data.rsr_data, get_dimmed_colour(rsr_colour))
    end
    if _computed_data.lsr_data and _computed_data.shortest_word ~= "lsr" then
      draw_curve(_computed_data.lsr_data, get_dimmed_colour(lsr_colour))
    end
    if _computed_data.rsl_data and _computed_data.shortest_word ~= "rsl" then
      draw_curve(_computed_data.rsl_data, get_dimmed_colour(rsl_colour))
    end

    if _computed_data.lsl_data and _computed_data.shortest_word == "lsl" then
      draw_curve(_computed_data.lsl_data, lsl_colour)
    elseif _computed_data.rsr_data and _computed_data.shortest_word == "rsr" then
      draw_curve(_computed_data.rsr_data, rsr_colour)
    elseif _computed_data.lsr_data and _computed_data.shortest_word == "lsr" then
      draw_curve(_computed_data.lsr_data, lsr_colour)
    elseif _computed_data.rsl_data and _computed_data.shortest_word == "rsl" then
      draw_curve(_computed_data.rsl_data, rsl_colour)
    end
  end
end
