local Common = require "Common"

-- Although the input for the functions are of type "Vehicle", the type is not explicitly used.
-- local Vehicle = require "Vehicle"

local Dubins = {}

--[[
curve_*_offset_* parameters for CSC (curve straight curve) are expected to be of this shape:
{
  orientation = [float],
  position = { x = [float], y = [float] }
}

It is expected that they are "normalized" into their "direction", so orientation and x should be positive, y should be
positive if the vehicle is going forward and negative if it's going in reverse.

The functions will adapt the sings as needed.

}]]
function Dubins.LSL(
  origin,
  destination,
  curve_1_offset_enter,
  curve_2_offset_enter,
  curve_offset_exit,
  curve_1_radius,
  curve_2_radius)

  -- Find where the vehicle enters the first curve
  -- cii
  local curve_in_in =
    Common.transform_local_to_world(
    {
      position = origin.position,
      orientation = origin.orientation
    },
    {
      position = {x = curve_1_offset_enter.position.x, y = curve_1_offset_enter.position.y},
      orientation = curve_1_offset_enter.orientation
    }
  )

  -- Find where is the center of rotation once the vehicle is in the curve
  local curve_in_in_left =
    Common.vector_rotate({x = 1, y = 0}, Common.over_2pi(math.pi / 2 + curve_in_in.orientation))

  -- cic
  local curve_in_center =
    Common.vector_add(
    Common.vector_mul(curve_in_in_left, curve_1_radius),
    curve_in_in.position
  )

  -- Find where the vehicle exits the last curve

  -- coo
  local curve_out_out =
    Common.transform_local_to_world(
    {
      position = destination.position,
      orientation = destination.orientation
    },
    {
      position = {x = -curve_offset_exit.position.x, y = curve_offset_exit.position.y},
      orientation = -curve_offset_exit.orientation
    }
  )

  -- Find where the center of rotation before exiting the last curve
  local curve_out_out_left =
    Common.vector_rotate({x = 1, y = 0}, Common.over_2pi(math.pi / 2 + curve_out_out.orientation))

  -- coc
  local curve_out_center =
    Common.vector_add(
    Common.vector_mul(curve_out_out_left, curve_2_radius),
    curve_out_out.position
  )

  --

  local center_to_center_segment = Common.vector_sub(curve_out_center, curve_in_center)
  local center_to_center_direction, center_to_center_length = Common.vector_normalize(center_to_center_segment)
  local center_to_center_orientation = math.atan2(center_to_center_direction.y, center_to_center_direction.x)

  -- Find the distance between the center of rotation and the where the vehicle will be completely out of the curve,
  -- straight.
  -- d_to_coc
  local distance_center_to_not_steering = Common.vector_distance(curve_out_center,destination.position)

  local straight_in_offset =
    Common.vector_mul(Common.vector_rotate(center_to_center_direction, -math.pi / 2), distance_center_to_not_steering)

  -- si
  local straigth_in = Common.vector_add(straight_in_offset, curve_in_center)
  -- so
  local straight_out = Common.vector_add(straigth_in, center_to_center_segment)

  --print(center_to_center_orientation)

  -- Find the point where the vehicle starts to de-steer after the first curve
  -- cio
  local curve_in_out = Common.transform_local_to_world(
    { position = straigth_in, orientation = center_to_center_orientation },
    { position = {x = -curve_offset_exit.position.x, y = curve_offset_exit.position.y},
      orientation = Common.clean_angle_over_2pi(curve_offset_exit.orientation + math.pi) }
  )

  -- Find the point where the vehicle is completely steering in the last curve
  -- coi
  local curve_out_in = Common.transform_local_to_world(
    { position = straight_out, orientation = center_to_center_orientation },
    { position = {x = curve_2_offset_enter.position.x, y = curve_2_offset_enter.position.y},
      orientation = Common.clean_angle_over_2pi(curve_2_offset_enter.orientation) }
  )

  local segment_1_length, origin_angle_in, origin_angle_out =
    Common.get_arc_data(curve_in_center, curve_1_radius, curve_in_in.position, curve_in_out.position)
  local segment_3_length, destination_angle_in, destination_angle_out =
    Common.get_arc_data(curve_out_center, curve_2_radius, curve_out_in.position, curve_out_out.position)

  --print(segment_1_length, origin_angle_in, origin_angle_out)
  return {
    origin = origin,
    curve_in_in = curve_in_in,
    curve_in_out = curve_in_out,
    curve_in_center = curve_in_center,
    curve_in_angles = {start = origin_angle_in, finish = origin_angle_out},
    curve_in_radius = curve_1_radius,

    straight_in = { position = straigth_in, orientation = center_to_center_orientation },
    straight_out = { position = straight_out, orientation = center_to_center_orientation },

    destination = destination,
    curve_out_in = curve_out_in,
    curve_out_out = curve_out_out,
    curve_out_center = curve_out_center,
    curve_out_angles = {start = destination_angle_in, finish = destination_angle_out},
    curve_out_radius = curve_2_radius,

    segments_lengths = {
      segment_1_length,
      center_to_center_length,
      segment_3_length
    },
    segments_length_total = segment_1_length + center_to_center_length + segment_3_length
  }
end

function Dubins.RSR(origin, destination)
  local center_to_center_segment = Common.vector_sub(destination.right_center, origin.right_center)
  local center_to_center_direction, center_to_center_length = Common.vector_normalize(center_to_center_segment)

  local departure_offset =
    Common.vector_mul(Common.vector_rotate(center_to_center_direction, math.pi / 2), origin.turning_radius)

  local leave_point = Common.vector_add(departure_offset, origin.right_center)
  local entry_point = Common.vector_add(leave_point, center_to_center_segment)

  local segment_1_length, origin_angle_in, origin_angle_out =
    Common.get_arc_data(origin.right_center, origin.turning_radius, leave_point, origin.position)
  local segment_3_length, destination_angle_in, destination_angle_out =
    Common.get_arc_data(destination.right_center, destination.turning_radius, destination.position, entry_point)

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

function Dubins.LSR(origin, destination)
  local center_to_center_segment = Common.vector_sub(destination.right_center, origin.left_center)
  local center_to_center_direction, center_to_center_length = Common.vector_normalize(center_to_center_segment)

  local straight_length =
    math.sqrt(center_to_center_length * center_to_center_length - origin.turning_radius * 2 * origin.turning_radius * 2)

  local angle_center_to_center___leave_point = -math.acos((origin.turning_radius * 2) / center_to_center_length)

  local leave_point_direction = Common.vector_rotate(center_to_center_direction, angle_center_to_center___leave_point)
  local leave_point_vector = Common.vector_mul(leave_point_direction, destination.turning_radius)

  local leave_point = Common.vector_add(origin.left_center, leave_point_vector)

  local straight_direction, _ =
    Common.vector_normalize(Common.vector_rotate(Common.vector_sub(origin.left_center, leave_point), -math.pi / 2))

  local entry_point = Common.vector_add(leave_point, Common.vector_mul(straight_direction, straight_length))

  local segment_1_length, origin_angle_in, origin_angle_out =
    Common.get_arc_data(origin.left_center, origin.turning_radius, origin.position, leave_point)
  local segment_3_length, destination_angle_in, destination_angle_out =
    Common.get_arc_data(destination.right_center, destination.turning_radius, entry_point, destination.position)

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

function Dubins.RSL(origin, destination)
  local center_to_center_segment = Common.vector_sub(destination.left_center, origin.right_center)
  local center_to_center_direction, center_to_center_length = Common.vector_normalize(center_to_center_segment)

  local straight_length =
    math.sqrt(center_to_center_length * center_to_center_length - origin.turning_radius * 2 * origin.turning_radius * 2)

  local angle_center_to_center___leave_point = math.acos((origin.turning_radius * 2) / center_to_center_length)

  local leave_point_direction = Common.vector_rotate(center_to_center_direction, angle_center_to_center___leave_point)
  local leave_point_vector = Common.vector_mul(leave_point_direction, destination.turning_radius)

  local leave_point = Common.vector_add(origin.right_center, leave_point_vector)

  local straight_direction, _ =
    Common.vector_normalize(Common.vector_rotate(Common.vector_sub(origin.right_center, leave_point), math.pi / 2))

  local entry_point = Common.vector_add(leave_point, Common.vector_mul(straight_direction, straight_length))

  local segment_1_length, origin_angle_in, origin_angle_out =
    Common.get_arc_data(origin.right_center, origin.turning_radius, origin.position, leave_point)
  local segment_3_length, destination_angle_in, destination_angle_out =
    Common.get_arc_data(destination.left_center, destination.turning_radius, entry_point, destination.position)

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

function Dubins.RLR(origin, destination)
  local center_to_center_segment = Common.vector_sub(destination.right_center, origin.right_center)
  local center_to_center_direction, center_to_center_length = Common.vector_normalize(center_to_center_segment)
  local angle_destination_center_new_circle_center
  if (2 * origin.turning_radius) > (center_to_center_length / 2) then
    angle_destination_center_new_circle_center = math.acos((center_to_center_length / 2) / (2 * origin.turning_radius))
  else
    angle_destination_center_new_circle_center = math.acos((2 * origin.turning_radius) / (center_to_center_length / 2))
  end

  local new_circle_center =
    Common.vector_add(
    origin.right_center,
    Common.vector_rotate(
      Common.vector_mul(center_to_center_direction, 2 * origin.turning_radius),
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
    Common.get_arc_data(origin.right_center, origin.turning_radius, origin.position, leave_point)
  local segment_3_length, destination_angle_in, destination_angle_out =
    Common.get_arc_data(destination.right_center, destination.turning_radius, entry_point, destination.position)

  local segment_2_length, center_angle_in, center_angle_out =
    Common.get_arc_data(new_circle_center, origin.turning_radius, leave_point, entry_point)

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

function Dubins.LRL(origin, destination)
  local center_to_center_segment = Common.vector_sub(destination.left_center, origin.left_center)
  local center_to_center_direction, center_to_center_length = Common.vector_normalize(center_to_center_segment)
  local angle_destination_center_new_circle_center
  if (2 * origin.turning_radius) > (center_to_center_length / 2) then
    angle_destination_center_new_circle_center = -math.acos((center_to_center_length / 2) / (2 * origin.turning_radius))
  else
    angle_destination_center_new_circle_center = -math.acos((2 * origin.turning_radius) / (center_to_center_length / 2))
  end

  local new_circle_center =
    Common.vector_add(
    origin.left_center,
    Common.vector_rotate(
      Common.vector_mul(center_to_center_direction, 2 * origin.turning_radius),
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
    Common.get_arc_data(origin.left_center, origin.turning_radius, origin.position, leave_point)
  local segment_3_length, destination_angle_in, destination_angle_out =
    Common.get_arc_data(destination.left_center, destination.turning_radius, entry_point, destination.position)

  local segment_2_length, center_angle_in, center_angle_out =
    Common.get_arc_data(new_circle_center, origin.turning_radius, leave_point, entry_point)

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

return Dubins
