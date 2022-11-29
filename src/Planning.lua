local Common = require "Common"
local Vector2 = require "Vector2"

-- luacheck: globals love

-- Although the input for the functions are of type "Vehicle", the type is not explicitly used.
-- local Vehicle = require "Vehicle"

local function print_(n_, v_)
  print(n_, v_.position.x .. " " .. v_.position.y .. " " .. v_.orientation)
end

local Planning = {
  LEFT = 1,
  CCW = 1,
  RIGHT = -1,
  CW = -1,
  START_STOPPED = "STOPPED",
  START_MOVING = "MOVING",
  FORWARD = 1,
  REVERSE = -1
}

function Planning.transform_local_to_world(local_frame, coords_to_transform)
  local new_orientation = Common.clean_angle_over_2pi(local_frame.orientation + coords_to_transform.orientation)
  local new_position = local_frame.position + coords_to_transform.position:rotate_copy(local_frame.orientation)

  return {
    orientation = new_orientation,
    position = new_position
  }
end

function Planning.transform_back(local_frame, coords_to_transform)
  local old_angle = Common.clean_angle_over_2pi(local_frame.orientation - coords_to_transform.orientation)
  local transformed = -coords_to_transform.position
  transformed:rotate(old_angle)

  return {
    orientation = old_angle,
    position = local_frame.position + transformed
  }
end

function Planning.Straight(origin_, destination_)
  local line_origin = Common.get_line_from_point_slope(origin_)
  local line_destination = Common.get_line_from_point_slope(destination_)

  local is_same_line = Common.is_same_line(line_origin, line_destination)

  return is_same_line and Common.equivalent(origin_.orientation, destination_.orientation)
end

function Planning.Curve_Straight(origin_, destination_, vehicle_data_, start_state_, turning_direction_in_, direction_)
  local line_destination = Common.get_line_from_point_slope(destination_.position, destination_.orientation)
  local td_i = turning_direction_in_
  local dir_as_text = "FORWARD"

  if direction_ == Planning.REVERSE then
    dir_as_text = "REVERSE"
  end

  assert(td_i == Planning.LEFT or td_i == Planning.RIGHT, "invalid direction")

  local found = false

  local min_ratio =
    vehicle_data_:get_estimated_values_for_ratio(dir_as_text, start_state_, 0.0).effective_joint_angle_ratio
  local max_ratio =
    vehicle_data_:get_estimated_values_for_ratio(dir_as_text, start_state_, 1.0).effective_joint_angle_ratio
  local lower_bound = min_ratio
  local upper_bound = max_ratio

  local return_dict = {
    input = {
      origin_ = origin_,
      destination_ = destination_,
      start_state_ = start_state_,
      turning_direction_in_ = turning_direction_in_,
      direction_ = direction_,
      line_destination = line_destination
    },
    test_count = 0,
    test_runs = {},
    segments_length_total = math.huge
  }

  while not found do
    return_dict.test_count = return_dict.test_count + 1

    if return_dict.test_count > 100 then
      -- Something is wrong, it shouldn't take that many tries.
      assert(false)
    end

    local should_report = false --return_dict.test_count > 50

    local current_run = {}
    local current_ratio_test = lower_bound + (upper_bound - lower_bound) / 2.0
    current_run.current_ratio_test = current_ratio_test
    current_run.lower_bound = lower_bound
    current_run.upper_bound = upper_bound
    current_run.min_ratio = min_ratio
    current_run.max_ratio = max_ratio

    if Common.equivalent(current_ratio_test, min_ratio) or Common.equivalent(current_ratio_test, max_ratio) then
      -- These should be tested on their own, not doing this check here results in an infinite loop. The rationale here
      -- is that it will either make it or break it: if the ratio does not give the results, the function will return
      -- without providing valid results and the receiving end will conclude "no path"; if this value is the right one,
      -- then the function will return valid data and everyone will be happy.😊
      found = true
    end

    -- res_in = {
    --   effective_joint_angle_ratio = desired_angle / self_.theoretical_max_angle,
    --   curve_radius = CR, --(estimated_radius_for_entry + estimated_radius_for_exit) / 2,
    --   curve_entry_location = curve_entry_location,
    --   curve_exit_location = curve_exit_location,
    --   estimated_radius_for_entry = estimated_radius_for_entry,
    --   estimated_radius_for_exit = estimated_radius_for_exit
    -- }
    local res_in = vehicle_data_:get_estimated_values_for_ratio(dir_as_text, start_state_, current_ratio_test)
    current_run.res_in = res_in

    local curve_in_offset_enter = res_in.curve_entry_location
    local curve_in_radius = res_in.curve_radius
    local curve_in_offset_exit = res_in.curve_exit_location

    local ci_cii = {
      position = Vector2(curve_in_offset_enter.position.x, curve_in_offset_enter.position.y * td_i),
      orientation = curve_in_offset_enter.orientation * td_i
    }

    local cio_si = {
      position = Vector2(curve_in_offset_exit.position.x, curve_in_offset_exit.position.y * td_i),
      orientation = curve_in_offset_exit.orientation * td_i
    }

    current_run.ci_cii = ci_cii
    current_run.cio_si = cio_si

    -- Find where the vehicle enters the first curve
    -- cii
    local curve_in_in = Planning.transform_local_to_world(origin_, ci_cii)
    current_run.curve_in_in = curve_in_in

    -- Find where is the center of rotation once the vehicle is in the curve
    local curve_in_in_side = Vector2(1, 0):rotate_copy(Common.over_2pi(curve_in_in.orientation + td_i * (math.pi / 2)))
    -- cic
    local curve_in_center = curve_in_in.position + (curve_in_in_side * curve_in_radius)
    current_run.curve_in_center = curve_in_center

    local pseudo_in_straight = Planning.transform_local_to_world(curve_in_in, cio_si)
    current_run.pseudo_in_straight = pseudo_in_straight

    local diff_angle = destination_.orientation - pseudo_in_straight.orientation
    current_run.diff_angle = diff_angle

    local tentative_curve_in_out = {
      position = curve_in_in.position:rotate_about_point_copy(curve_in_center, diff_angle),
      orientation = curve_in_in.orientation + diff_angle
    }
    current_run.tentative_curve_in_out = tentative_curve_in_out

    local tentative_in_straight = {
      position = pseudo_in_straight.position:rotate_about_point_copy(curve_in_center, diff_angle),
      orientation = pseudo_in_straight.orientation + diff_angle
    }
    current_run.tentative_in_straight = tentative_in_straight

    local MARGIN_OF_ERROR = 0.00001

    local distance_to_line, point_on_line =
      Common.get_distance_line_point(line_destination, tentative_in_straight.position)
    current_run.distance_to_line = distance_to_line

    if Common.equivalent(distance_to_line, 0.0) then
      -- we get a match
      found = true

      local is_in_front = function()
        -- Move the tentative_straight_out in local frame of the vehicle destination_
        local local_in_straight = tentative_in_straight.position - destination_.position
        local_in_straight:rotate(-destination_.orientation)
        -- check if in front
        if direction_ == Planning.REVERSE then
          return local_in_straight.x < 0.0
        else
          return local_in_straight.x > 0.0
        end
      end

      if not is_in_front() then
        -- We do further calculations if it is not in front; if those values are not supplied, the receiving end will
        -- assume "no path".
        return_dict.res_in = res_in
        return_dict.ci_cii = ci_cii
        return_dict.cio_si = cio_si
        return_dict.curve_in_in = curve_in_in
        return_dict.curve_in_center = curve_in_center

        return_dict.in_straight = tentative_in_straight

        local curve_in_out = tentative_curve_in_out
        return_dict.curve_in_out = curve_in_out

        local status2, segment_3_length, origin_angle_in, origin_angle_out =
          pcall(
          Common.get_arc_data,
          curve_in_center,
          curve_in_radius,
          curve_in_in.position,
          curve_in_out.position,
          direction_ * td_i,
          MARGIN_OF_ERROR * 100
        )

        if status2 then
          return_dict.curve_in_angles = {start = origin_angle_in, finish = origin_angle_out}

          local straigth_length = (tentative_in_straight.position - destination_.position):length()
          return_dict.segments_lengths = {
            straigth_length,
            segment_3_length
          }

          return_dict.segments_length_total =
            straigth_length + ci_cii.position:length() + segment_3_length + cio_si.position:length()
        end
      end
    else
      -- check wheter we've overshot or we've undershot
      local distance_to_point_on_line = (point_on_line - curve_in_center):length()
      local distance_to_point = (tentative_in_straight.position - curve_in_center):length()

      current_run.distance_to_point_on_line = distance_to_point_on_line
      current_run.distance_to_point = distance_to_point

      if Common.equivalent(distance_to_point_on_line, distance_to_point) then
        -- we've explored all the space we had, no path.
        found = true
      elseif distance_to_point > distance_to_point_on_line then
        -- we're too far away
        -- this means that the chosen ratio was too small
        lower_bound = current_ratio_test
      else -- distance_to_point < distance_to_point_on_line then
        -- we overshot
        -- this means that the chosen ratio was too big
        upper_bound = current_ratio_test
      end
    end

    if should_report then
      require "pl/pretty".dump(current_run)
    end

    table.insert(return_dict.test_runs, current_run)
  end

  return return_dict
end

function Planning.Straight_Curve(origin_, destination_, vehicle_data_, turning_direction_out_, direction_)
  local line_origin = Common.get_line_from_point_slope(origin_.position, origin_.orientation)
  local td_o = turning_direction_out_
  local dir_as_text = "FORWARD"

  if direction_ == Planning.REVERSE then
    dir_as_text = "REVERSE"
  end

  assert(td_o == Planning.LEFT or td_o == Planning.RIGHT, "invalid direction")

  local found = false

  local min_ratio = vehicle_data_:get_estimated_values_for_ratio(dir_as_text, "MOVING", 0.0).effective_joint_angle_ratio
  local max_ratio = vehicle_data_:get_estimated_values_for_ratio(dir_as_text, "MOVING", 1.0).effective_joint_angle_ratio
  local lower_bound = min_ratio
  local upper_bound = max_ratio

  local return_dict = {
    input = {
      origin_ = origin_,
      destination_ = destination_,
      turning_direction_out_ = turning_direction_out_,
      direction_ = direction_,
      line_origin = line_origin
    },
    test_count = 0,
    test_runs = {},
    segments_length_total = math.huge
  }

  while not found do
    return_dict.test_count = return_dict.test_count + 1
    -- print("loop", return_dict.test_count)

    if return_dict.test_count > 100 then
      -- Something is wrong, it shouldn't take that many tries.
      assert(false)
    end

    local should_report = false --return_dict.test_count > 50

    local current_run = {}
    local current_ratio_test = lower_bound + (upper_bound - lower_bound) / 2.0
    current_run.current_ratio_test = current_ratio_test
    current_run.lower_bound = lower_bound
    current_run.upper_bound = upper_bound
    current_run.min_ratio = min_ratio
    current_run.max_ratio = max_ratio

    if Common.equivalent(current_ratio_test, min_ratio) or Common.equivalent(current_ratio_test, max_ratio) then
      -- These should be tested on their own, not doing this check here results in an infinite loop. The rationale here
      -- is that it will either make it or break it: if the ratio does not give the results, the function will return
      -- without providing valid results and the receiving end will conclude "no path"; if this value is the right one,
      -- then the function will return valid data and everyone will be happy.😊
      found = true
    end

    -- res_out = {
    --   effective_joint_angle_ratio = desired_angle / self_.theoretical_max_angle,
    --   curve_radius = CR, --(estimated_radius_for_entry + estimated_radius_for_exit) / 2,
    --   curve_entry_location = curve_entry_location,
    --   curve_exit_location = curve_exit_location,
    --   estimated_radius_for_entry = estimated_radius_for_entry,
    --   estimated_radius_for_exit = estimated_radius_for_exit
    -- }
    local res_out = vehicle_data_:get_estimated_values_for_ratio(dir_as_text, "MOVING", current_ratio_test)
    current_run.res_out = res_out

    local curve_out_radius = res_out.curve_radius
    local curve_out_offset_exit = res_out.curve_exit_location

    local coo_co = {
      position = Vector2(curve_out_offset_exit.position.x, curve_out_offset_exit.position.y * td_o),
      orientation = curve_out_offset_exit.orientation * td_o
    }
    current_run.coo_co = coo_co

    -- Find where the vehicle exits the last curve
    -- coo
    local curve_out_out = Planning.transform_back(destination_, coo_co)
    current_run.curve_out_out = curve_out_out

    -- Find where the center of rotation before exiting the last curve
    local curve_out_out_side =
      Vector2(1, 0):rotate_copy(Common.over_2pi(curve_out_out.orientation + td_o * (math.pi / 2)))

    -- coc
    local curve_out_center = curve_out_out.position + (curve_out_out_side * curve_out_radius)
    current_run.curve_out_center = curve_out_center

    local curve_out_offset_enter = res_out.curve_entry_location

    local so_coi = {
      position = Vector2(curve_out_offset_enter.position.x, curve_out_offset_enter.position.y * td_o),
      orientation = curve_out_offset_enter.orientation * td_o
    }
    current_run.so_coi = so_coi

    local pseudo_straight_out = Planning.transform_back(curve_out_out, so_coi)
    current_run.pseudo_straight_out = pseudo_straight_out

    local diff_angle = origin_.orientation - pseudo_straight_out.orientation
    current_run.diff_angle = diff_angle

    local tentative_curve_out_in = {
      position = curve_out_out.position:rotate_about_point_copy(curve_out_center, diff_angle),
      orientation = curve_out_out.orientation + diff_angle
    }
    current_run.tentative_curve_out_in = tentative_curve_out_in

    local tentative_straight_out = {
      position = pseudo_straight_out.position:rotate_about_point_copy(curve_out_center, diff_angle),
      orientation = pseudo_straight_out.orientation + diff_angle
    }
    current_run.tentative_straight_out = tentative_straight_out

    local MARGIN_OF_ERROR = 0.00001

    local distance_to_line, point_on_line = Common.get_distance_line_point(line_origin, tentative_straight_out.position)
    current_run.distance_to_line = distance_to_line

    if Common.equivalent(distance_to_line, 0.0) then
      -- we get a match
      found = true

      local is_in_front = function()
        -- Move the tentative_straight_out in local frame of the vehicle origin_
        local local_straight_out = tentative_straight_out.position - origin_.position
        local_straight_out:rotate(-origin_.orientation)
        -- check if in front
        if direction_ == Planning.REVERSE then
          return local_straight_out.x < 0.0
        else
          return local_straight_out.x > 0.0
        end
      end

      if is_in_front() then
        -- We do further calculations if it is in front; if those values are not supplied, the receiving end will assume
        -- "no path".
        return_dict.res_out = res_out
        return_dict.coo_co = coo_co
        return_dict.curve_out_out = curve_out_out
        return_dict.curve_out_center = curve_out_center

        return_dict.straight_out = tentative_straight_out

        local curve_out_in = tentative_curve_out_in --Planning.transform_local_to_world(straight_out, so_coi)
        return_dict.curve_out_in = curve_out_in

        local status2, segment_3_length, destination_angle_in, destination_angle_out =
          pcall(
          Common.get_arc_data,
          curve_out_center,
          curve_out_radius,
          curve_out_in.position,
          curve_out_out.position,
          direction_ * td_o,
          MARGIN_OF_ERROR * 100
        )

        if status2 then
          return_dict.curve_out_angles = {start = destination_angle_in, finish = destination_angle_out}

          local straigth_length = (tentative_straight_out.position - origin_.position):length()
          return_dict.segments_lengths = {
            straigth_length,
            segment_3_length
          }

          return_dict.segments_length_total =
            straigth_length + so_coi.position:length() + segment_3_length + coo_co.position:length()
        end
      end
    else
      -- check wheter we've overshot or we've undershot

      local distance_to_point_on_line = (point_on_line - curve_out_center):length()
      local distance_to_point = (tentative_straight_out.position - curve_out_center):length()

      current_run.distance_to_point_on_line = distance_to_point_on_line
      current_run.distance_to_point = distance_to_point

      if Common.equivalent(distance_to_point_on_line, distance_to_point) then
        -- we've explored all the space we had, no path.
        found = true
      elseif distance_to_point > distance_to_point_on_line then
        -- we're too far away
        -- this means that the chosen ratio was too small
        lower_bound = current_ratio_test
      else -- distance_to_point < distance_to_point_on_line then
        -- we overshot
        -- this means that the chosen ratio was too big
        upper_bound = current_ratio_test
      end
    end

    if should_report then
      require "pl/pretty".dump(current_run)
    end

    table.insert(return_dict.test_runs, current_run)
  end

  return return_dict
end

--[[
Test the "words" Curve-Straight-Curve: LSL, RSR, LSR and RSL; they all use a similar approach, with the minor differences
in the signs.
]]
function Planning.ComputePath(
  origin_,
  destination_,
  vehicle_data_,
  start_state_,
  turning_direction_in_,
  turning_direction_out_,
  ratio_in_,
  ratio_out_,
  direction_)
  local ratio_in = ratio_in_ or -1
  local ratio_out = ratio_out_ or -1
  local td_i = turning_direction_in_
  local td_o = turning_direction_out_

  assert(td_i == Planning.LEFT or td_i == Planning.RIGHT, "invalid direction")
  assert(td_o == Planning.LEFT or td_o == Planning.RIGHT, "invalid direction")
  assert(direction_ == Planning.FORWARD or direction_ == Planning.REVERSE, "invalid direction")

  local dir_as_text = "FORWARD"

  if direction_ == Planning.REVERSE then
    dir_as_text = "REVERSE"
  end

  local res_in = vehicle_data_:get_estimated_values_for_ratio(dir_as_text, start_state_, ratio_in)
  -- require "pl/pretty".dump(res_in)

  local curve_in_offset_enter = res_in.curve_entry_location
  local curve_in_radius = res_in.curve_radius
  local curve_in_offset_exit = res_in.curve_exit_location

  -- print("res_out")
  local res_out = vehicle_data_:get_estimated_values_for_ratio(dir_as_text, "MOVING", ratio_out)
  -- require "pl/pretty".dump(res_out)

  local curve_out_offset_enter = res_out.curve_entry_location
  local curve_out_radius = res_out.curve_radius
  local curve_out_offset_exit = res_out.curve_exit_location

  local ci_cii = {
    position = Vector2(curve_in_offset_enter.position.x, curve_in_offset_enter.position.y * td_i),
    orientation = curve_in_offset_enter.orientation * td_i
  }

  local cio_si = {
    position = Vector2(curve_in_offset_exit.position.x, curve_in_offset_exit.position.y * td_i),
    orientation = curve_in_offset_exit.orientation * td_i
  }

  local so_coi = {
    position = Vector2(curve_out_offset_enter.position.x, curve_out_offset_enter.position.y * td_o),
    orientation = curve_out_offset_enter.orientation * td_o
  }

  local coo_co = {
    position = Vector2(curve_out_offset_exit.position.x, curve_out_offset_exit.position.y * td_o),
    orientation = curve_out_offset_exit.orientation * td_o
  }

  -- This will allow us to output the data and use the results more easily.
  local input = {
    origin_ = origin_,
    destination_ = destination_,
    curve_in_offset_enter_ = curve_in_offset_enter,
    curve_out_offset_enter_ = curve_out_offset_enter,
    curve_in_offset_exit_ = curve_in_offset_exit,
    curve_out_offset_exit_ = curve_out_offset_exit,
    curve_in_radius_ = curve_in_radius,
    curve_out_radius_ = curve_out_radius,
    ci_cii = ci_cii,
    cio_si = cio_si,
    so_coi = so_coi,
    coo_co = coo_co,
    turning_direction_in_ = turning_direction_in_,
    turning_direction_out_ = turning_direction_out_,
    ratio_in_ = ratio_in_,
    ratio_out_ = ratio_out_,
    direction_ = direction_
  }

  local return_dict = {
    input = input,
    segments_length_total = math.huge
  }

  -- Find where the vehicle enters the first curve
  -- cii
  local curve_in_in = Planning.transform_local_to_world(origin_, ci_cii)
  return_dict.curve_in_in = curve_in_in

  -- Find where is the center of rotation once the vehicle is in the curve
  local curve_in_in_side = Vector2(1, 0):rotate_copy(Common.over_2pi(curve_in_in.orientation + td_i * (math.pi / 2)))
  -- cic
  local curve_in_center = curve_in_in.position + (curve_in_in_side * curve_in_radius)
  return_dict.curve_in_center = curve_in_center

  -- Find where the vehicle exits the last curve
  -- coo
  local curve_out_out = Planning.transform_back(destination_, coo_co)
  return_dict.curve_out_out = curve_out_out

  -- Find where the center of rotation before exiting the last curve
  local curve_out_out_side =
    Vector2(1, 0):rotate_copy(Common.over_2pi(curve_out_out.orientation + td_o * (math.pi / 2)))

  -- coc
  local curve_out_center = curve_out_out.position + (curve_out_out_side * curve_out_radius)
  return_dict.curve_out_center = curve_out_center

  -- Early check; if both circles are not going in the same "direction", and they overlap, there is no solution.
  if
    td_i ~= td_o and
      Common.do_circles_overlap(
        {radius = curve_in_radius, position = curve_in_center},
        {radius = curve_out_radius, position = curve_out_center}
      )
   then
    -- print("no solution circles_overlap")
    return return_dict
  end

  local a_point_on_cic_si_circle = Planning.transform_local_to_world(curve_in_in, cio_si)
  -- curve in exit radius
  local curve_in_exit_radius = a_point_on_cic_si_circle.position:distance(curve_in_center)
  return_dict.a_point_on_cic_si_circle = a_point_on_cic_si_circle
  return_dict.curve_in_exit_radius = curve_in_exit_radius

  local a_point_on_cic_si_circle_line =
    Common.get_line_from_point_slope(a_point_on_cic_si_circle.position, a_point_on_cic_si_circle.orientation)

  local tangent_i_r, tangent_i_p = Common.get_distance_line_point(a_point_on_cic_si_circle_line, curve_in_center)
  return_dict.a_point_on_cic_si_circle_line = a_point_on_cic_si_circle_line
  return_dict.tangent_i_r = tangent_i_r
  return_dict.tangent_i_p = tangent_i_p

  local a_point_on_coc_so_circle = Planning.transform_back(curve_out_out, so_coi)
  -- curve out enter radius
  local curve_out_enter_radius = a_point_on_coc_so_circle.position:distance(curve_out_center)
  return_dict.a_point_on_coc_so_circle = a_point_on_coc_so_circle
  return_dict.curve_out_enter_radius = curve_out_enter_radius

  local a_point_on_coc_so_circle_line =
    Common.get_line_from_point_slope(a_point_on_coc_so_circle.position, a_point_on_coc_so_circle.orientation)

  local tangent_o_r, tangent_o_p = Common.get_distance_line_point(a_point_on_coc_so_circle_line, curve_out_center)
  return_dict.a_point_on_coc_so_circle_line = a_point_on_coc_so_circle_line
  return_dict.tangent_o_r = tangent_o_r
  return_dict.tangent_o_p = tangent_o_p

  -- Early check: if both circle are going in the same "direction", and one is completely within the other, there is no
  -- solution
  if
    td_i == td_o and
      Common.does_one_circle_cover_circle(
        {radius = tangent_i_r, position = curve_in_center},
        {radius = tangent_o_r, position = curve_out_center}
      )
   then
    -- print("no solution one_circle_cover_circle")
    return return_dict
  end

  -- find where those circles intersect with a common tangent
  local tangent =
    Common.get_tangent_to_two_circles(
    curve_in_center,
    curve_out_center,
    direction_ * -td_i * tangent_i_r,
    direction_ * -td_o * tangent_o_r
  )
  local intersection_points_in =
    Common.find_intersection_line_circle(tangent, {position = curve_in_center, radius = tangent_i_r})
  local intersection_points_out =
    Common.find_intersection_line_circle(tangent, {position = curve_out_center, radius = tangent_o_r})
  return_dict.tangent = tangent

  if #intersection_points_in == 2 then
    print("intersection_points_in has two points")
  -- return {segments_length_total = math.huge, input = input}
  end
  if #intersection_points_out == 2 then
    print("intersection_points_out has twop points")
  -- return {segments_length_total = math.huge, input = input}
  end
  return_dict.ci_intersect = intersection_points_in[1]
  return_dict.co_intersect = intersection_points_out[1]

  if #intersection_points_in == 0 or #intersection_points_out == 0 then
    print("no intersection points")
    return return_dict
  end

  local tangent_direction = intersection_points_out[1] - intersection_points_in[1]

  tangent_direction = tangent_direction * direction_

  tangent_direction:normalize()
  local tangent_orientation = Common.atan2(tangent_direction.y, tangent_direction.x)
  return_dict.tangent_direction = tangent_direction
  return_dict.tangent_orientation = tangent_orientation

  local curve_in_exit_radius_s = 0
  if curve_in_exit_radius > tangent_i_r then
    curve_in_exit_radius_s = math.sqrt(curve_in_exit_radius * curve_in_exit_radius - tangent_i_r * tangent_i_r)
  elseif tangent_i_r > curve_in_exit_radius then
    curve_in_exit_radius_s = math.sqrt(tangent_i_r * tangent_i_r - curve_in_exit_radius * curve_in_exit_radius)
  --else curve_in_exit_radius == tangent_i_r
  -- do nothing
  end

  if
    direction_ == Planning.FORWARD and
      curve_in_in.position:distance(a_point_on_cic_si_circle.position) < curve_in_in.position:distance(tangent_i_p)
   then
    curve_in_exit_radius_s = -curve_in_exit_radius_s
  elseif direction_ == Planning.REVERSE then
    -- Note: althought his appears to be "working" as expected with the current data set, there may be subleties in
    -- some data sets that would require the algorithm here to be tuned.
    curve_in_exit_radius_s = -curve_in_exit_radius_s
  end
  return_dict.curve_in_exit_radius_s = curve_in_exit_radius_s

  local curve_out_enter_radius_s = 0
  if curve_out_enter_radius > tangent_o_r then
    curve_out_enter_radius_s = math.sqrt(curve_out_enter_radius * curve_out_enter_radius - tangent_o_r * tangent_o_r)
  elseif tangent_o_r > curve_out_enter_radius then
    curve_out_enter_radius_s = math.sqrt(tangent_o_r * tangent_o_r - curve_out_enter_radius * curve_out_enter_radius)
  --else curve_out_enter_radius == tangent_o_r
  -- do nothing
  end

  return_dict.curve_out_enter_radius_s = curve_out_enter_radius_s

  -- si
  local straight_in = {
    position = intersection_points_in[1] + (tangent_direction * curve_in_exit_radius_s),
    orientation = tangent_orientation
  }
  return_dict.straight_in = straight_in

  -- so
  local straight_out = {
    position = intersection_points_out[1] + (tangent_direction * -curve_out_enter_radius_s),
    orientation = tangent_orientation
  }
  return_dict.straight_out = straight_out

  local straigth_length = straight_in.position:distance(straight_out.position)
  return_dict.straigth_length = straigth_length

  -- Find the point where the vehicle starts to de-steer after the first curve
  -- cio
  local curve_in_out = Planning.transform_back(straight_in, cio_si)
  return_dict.curve_in_out = curve_in_out

  local curve_out_in = Planning.transform_local_to_world(straight_out, so_coi)
  return_dict.curve_out_in = curve_out_in

  local status1, segment_1_length, origin_angle_in, origin_angle_out =
    pcall(
    Common.get_arc_data,
    curve_in_center,
    curve_in_radius,
    curve_in_in.position,
    curve_in_out.position,
    direction_ * td_i
  )

  local status2, segment_3_length, destination_angle_in, destination_angle_out =
    pcall(
    Common.get_arc_data,
    curve_out_center,
    curve_out_radius,
    curve_out_in.position,
    curve_out_out.position,
    direction_ * td_o
  )

  if not status1 or not status2 then
    if not status1 then
      print(
        "oops1",
        "td_i",
        td_i,
        "td_o",
        td_o,
        "ratio_in_",
        ratio_in_,
        "ratio_out_",
        ratio_out_,
        "direction_",
        direction_
      )
    end
    if not status2 then
      print(
        "oops2",
        "td_i",
        td_i,
        "td_o",
        td_o,
        "ratio_in_",
        ratio_in_,
        "ratio_out_",
        ratio_out_,
        "direction_",
        direction_
      )
    end

    return return_dict
  end
  return_dict.curve_in_angles = {start = origin_angle_in, finish = origin_angle_out}
  return_dict.curve_out_angles = {start = destination_angle_in, finish = destination_angle_out}
  return_dict.segments_lengths = {
    segment_1_length,
    straigth_length,
    segment_3_length
  }
  return_dict.segments_length_total =
    ci_cii.position:length() + segment_1_length + cio_si.position:length() + straigth_length + so_coi.position:length() +
    segment_3_length +
    coo_co.position:length()

  return return_dict
end

return Planning
