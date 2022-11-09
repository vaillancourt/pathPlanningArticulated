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

--[[
A generic approach to planning path. The four "words" (LSL, RSR, LSR and RSL) use the same approach,
with the minor differences in the signs.




]]
function Planning.ComputePath(
  origin_,
  destination_,
  vehicle_data_,
  start_state_,
  turning_direction_in_,
  turning_direction_out_,
  cycle_,
  ratio_in_,
  ratio_out_,
  direction_)
  cycle_ = cycle_ or 0
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
