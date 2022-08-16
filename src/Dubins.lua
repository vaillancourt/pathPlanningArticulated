local Common = require "Common"

-- Although the input for the functions are of type "Vehicle", the type is not explicitly used.
-- local Vehicle = require "Vehicle"

local Dubins = {}

function Dubins.LSL(origin, destination)
  local center_to_center_segment = Common.vector_sub(destination.left_center, origin.left_center)
  local center_to_center_direction, center_to_center_length = Common.vector_normalize(center_to_center_segment)

  local departure_offset =
    Common.vector_mul(Common.vector_rotate(center_to_center_direction, -math.pi / 2), origin.turning_radius)

  local leave_point = Common.vector_add(departure_offset, origin.left_center)
  local entry_point = Common.vector_add(leave_point, center_to_center_segment)

  local segment_1_length, origin_angle_in, origin_angle_out =
    Common.get_arc_data(origin.left_center, origin.turning_radius, origin.position, leave_point)
  local segment_3_length, destination_angle_in, destination_angle_out =
    Common.get_arc_data(destination.left_center, destination.turning_radius, entry_point, destination.position)

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
