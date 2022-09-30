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
  START_MOVING = "MOVING"
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
  turning_direction_out_)
  local td_i = turning_direction_in_
  local td_o = turning_direction_out_

  assert(td_i == Planning.LEFT or td_i == Planning.RIGHT, "invalid direction")
  assert(td_o == Planning.LEFT or td_o == Planning.RIGHT, "invalid direction")

  local data_key_root = "FORWARD."

  local find_curve_data = function(key_)
    local entry_index = vehicle_data_.data[key_].last_entry
    local last_entry = vehicle_data_.data[key_].entries[entry_index]
    local position = last_entry.rear_body_pos
    local orientation = last_entry.rear_body_angle
    local turning_radius = last_entry.turning_radius

    return {position = position, orientation = orientation}, turning_radius
  end

  local curve_in_offset_enter_, curve_in_radius_ = find_curve_data(data_key_root .. start_state_ .. "." .. "STEERING")
  local curve_out_offset_enter_, curve_out_radius_ = find_curve_data(data_key_root .. "MOVING" .. "." .. "STEERING")
  local curve_offset_exit_, _ = find_curve_data(data_key_root .. "MOVING" .. "." .. "DESTEERING")

  local ci_cii = {
    position = Vector2(curve_in_offset_enter_.position.x, curve_in_offset_enter_.position.y * td_i),
    orientation = curve_in_offset_enter_.orientation * td_i
  }

  local cio_si = {
    position = Vector2(curve_offset_exit_.position.x, curve_offset_exit_.position.y * td_i),
    orientation = curve_offset_exit_.orientation * td_i
  }

  local so_coi = {
    position = Vector2(curve_out_offset_enter_.position.x, curve_out_offset_enter_.position.y * td_o),
    orientation = curve_out_offset_enter_.orientation * td_o
  }

  local coo_co = {
    position = Vector2(curve_offset_exit_.position.x, curve_offset_exit_.position.y * td_o),
    orientation = curve_offset_exit_.orientation * td_o
  }

  -- This will allow us to output the data and use the results more easily.
  local input = {
    origin_ = origin_,
    destination_ = destination_,
    curve_in_offset_enter_ = curve_in_offset_enter_,
    curve_out_offset_enter_ = curve_out_offset_enter_,
    curve_offset_exit_ = curve_offset_exit_,
    curve_in_radius_ = curve_in_radius_,
    curve_out_radius_ = curve_out_radius_,
    ci_cii = ci_cii,
    cio_si = cio_si,
    so_coi = so_coi,
    coo_co = coo_co,
    turning_direction_in_ = turning_direction_in_,
    turning_direction_out_ = turning_direction_out_
  }

  -- Find where the vehicle enters the first curve
  -- cii
  local curve_in_in = Planning.transform_local_to_world(origin_, ci_cii)

  -- Find where is the center of rotation once the vehicle is in the curve
  local curve_in_in_side = Vector2(1, 0):rotate_copy(Common.over_2pi(curve_in_in.orientation + td_i * (math.pi / 2)))

  -- cic
  local curve_in_center = curve_in_in.position + (curve_in_in_side * curve_in_radius_)

  -- find the radii of the straing-in circle (w.r.t. the center of the in circle), and the straight-out circle (w.r.t.
  -- the center of the out circle)

  local a_point_on_cic_si_circle = Planning.transform_local_to_world(curve_in_in, cio_si)
  -- curve in exit radius
  local cier = a_point_on_cic_si_circle.position:distance(curve_in_center)

  local a_point_on_cic_si_circle_line =
    Common.get_line_from_point_slope(a_point_on_cic_si_circle.position, a_point_on_cic_si_circle.orientation)

  local tangent_i_r, tangent_i_p = Common.get_distance_line_point(a_point_on_cic_si_circle_line, curve_in_center)

  -- Find where the vehicle exits the last curve
  -- coo
  local curve_out_out = Planning.transform_back(destination_, coo_co)

  -- Find where the center of rotation before exiting the last curve
  local curve_out_out_side =
    Vector2(1, 0):rotate_copy(Common.over_2pi(curve_out_out.orientation + td_o * (math.pi / 2)))

  -- coc
  local curve_out_center = curve_out_out.position + (curve_out_out_side * curve_out_radius_)

  local a_point_on_coc_so_circle = Planning.transform_back(curve_out_out, so_coi)
  -- curve out enter radius
  local coer = a_point_on_coc_so_circle.position:distance(curve_out_center)

  local a_point_on_coc_so_circle_line =
    Common.get_line_from_point_slope(a_point_on_coc_so_circle.position, a_point_on_coc_so_circle.orientation)

  local tangent_o_r, tangent_o_p = Common.get_distance_line_point(a_point_on_coc_so_circle_line, curve_out_center)

  -- find where those circles intersect with a common tangent
  local tangent =
    Common.get_tangent_to_two_circles(curve_in_center, curve_out_center, -td_i * tangent_i_r, -td_o * tangent_o_r)
  local intersection_points_in =
    Common.find_intersection_line_circle(tangent, {position = curve_in_center, radius = tangent_i_r})
  local intersection_points_out =
    Common.find_intersection_line_circle(tangent, {position = curve_out_center, radius = tangent_o_r})

  if #intersection_points_in == 2 then
    -- print("intersection_points_in has two points")
    return {segments_length_total = math.huge}
  end
  if #intersection_points_out == 2 then
    -- print("intersection_points_out has twop points")
    return {segments_length_total = math.huge}
  end

  if #intersection_points_in == 0 or #intersection_points_out == 0 then
    -- print("no intersection points")
    return {segments_length_total = math.huge}
  end

  local tangent_direction = intersection_points_out[1] - intersection_points_in[1]
  tangent_direction:normalize()
  local tangent_orientation = Common.atan2(tangent_direction.y, tangent_direction.x)

  local cier_s = 0
  if cier > tangent_i_r then
    cier_s = math.sqrt(cier * cier - tangent_i_r * tangent_i_r)
  elseif tangent_i_r > cier then
    cier_s = math.sqrt(tangent_i_r * tangent_i_r - cier * cier)
  --else cier == tangent_i_r
  -- do nothing
  end

  local coer_s = 0
  if coer > tangent_o_r then
    coer_s = math.sqrt(coer * coer - tangent_o_r * tangent_o_r)
  elseif tangent_o_r > coer then
    coer_s = math.sqrt(tangent_o_r * tangent_o_r - coer * coer)
  --else coer == tangent_o_r
  -- do nothing
  end

  -- si
  local straigth_in = {
    position = intersection_points_in[1] + (tangent_direction * cier_s),
    orientation = tangent_orientation
  }

  -- so
  local straight_out = {
    position = intersection_points_out[1] + (tangent_direction * -coer_s),
    orientation = tangent_orientation
  }

  local straigth_length = straigth_in.position:distance(straight_out.position)

  -- Find the point where the vehicle starts to de-steer after the first curve
  -- cio
  local curve_in_out = Planning.transform_back(straigth_in, cio_si)

  local curve_out_in = Planning.transform_local_to_world(straight_out, so_coi)

  local segment_1_length, origin_angle_in, origin_angle_out =
    Common.get_arc_data(curve_in_center, curve_in_radius_, curve_in_in.position, curve_in_out.position, td_i)

  local segment_3_length, destination_angle_in, destination_angle_out =
    Common.get_arc_data(curve_out_center, curve_out_radius_, curve_out_in.position, curve_out_out.position, td_o)

  return {
    input = input,
    curve_in_in = curve_in_in,
    curve_in_out = curve_in_out,
    curve_in_center = curve_in_center,
    curve_in_angles = {start = origin_angle_in, finish = origin_angle_out},
    curve_in_radius = curve_in_radius_,
    cier_s = cier_s,
    ci_intersect = intersection_points_in[1],
    a_point_on_cic_si_circle = a_point_on_cic_si_circle,
    a_point_on_cic_si_circle_line = a_point_on_cic_si_circle_line,
    tangent_i_r = tangent_i_r,
    tangent_i_p = tangent_i_p,
    straight_in = straigth_in,
    straight_out = straight_out,
    cier = cier,
    coer = coer,
    curve_out_in = curve_out_in,
    curve_out_out = curve_out_out,
    curve_out_center = curve_out_center,
    curve_out_angles = {start = destination_angle_in, finish = destination_angle_out},
    curve_out_radius = curve_out_radius_,
    coer_s = coer_s,
    co_intersect = intersection_points_out[1],
    a_point_on_coc_so_circle = a_point_on_coc_so_circle,
    a_point_on_coc_so_circle_line = a_point_on_coc_so_circle_line,
    tangent_o_r = tangent_o_r,
    tangent_o_p = tangent_o_p,
    tangent = tangent,
    segments_lengths = {
      segment_1_length,
      straigth_length,
      segment_3_length
    },
    segments_length_total = segment_1_length + straigth_length + segment_3_length
  }
end

return Planning
