local Common = {}

function Common.world_to_gfx(world_coord)
  -- for now, 1 meter is one pixel
  return world_coord
end

function Common.v_to_t(x, y)
  return {x, y}
end

function Common.t_to_v(t)
  return t[1], t[2]
end

function Common.dot_product(x1, y1, x2, y2)
  return (x1 * x2) + (y1 * y2)
end

function Common.vector_length_2(x, y)
  return x * x + y * y
end

function Common.vector_length(x, y)
  return math.sqrt(Common.vector_length_2(x, y))
end

function Common.vector_normalize(x, y)
  if type(x) == "table" then
    y = x.y
    x = x.x
    local length = Common.vector_length(x, y)
    return {x = x / length, y = y / length}, length
  elseif x and y then
    local length = Common.vector_length(x, y)
    return x / length, y / length, length
  end
  assert(false)
end

function Common.vector_add(x1, y1, x2, y2)
  if type(x1) == "table" and type(y1) == "table" then
    local v1, v2 = x1, y1
    return {x = v1.x + v2.x, y = v1.y + v2.y}
  elseif x1 and y1 and x2 and y2 then
    return x1 + x2, y1 + y2
  end
  assert(false)
end

function Common.vector_mul(x, y, val)
  if type(x) == "table" then
    val = y
    y = x.y
    x = x.x
    return {x = x * val, y = y * val}
  elseif x and y and val then
    return x * val, y * val
  end
  assert(false)
end

function Common.vector_sub(x1, y1, x2, y2)
  if type(x1) == "table" and type(y1) == "table" then
    local v1, v2 = x1, y1
    return {x = v1.x - v2.x, y = v1.y - v2.y}
  elseif x1 and y1 and x2 and y2 then
    return x1 - x2, y1 - y2
  end
  assert(false)
end

function Common.vector_rotate(v, angle_over_2pi)
  return {
    x = math.cos(angle_over_2pi) * v.x - math.sin(angle_over_2pi) * v.y,
    y = math.sin(angle_over_2pi) * v.x + math.cos(angle_over_2pi) * v.y
  }
end

function Common.vector_print(x, y, name)
  print(type(x))
  require "pl/pretty".dump(x)
  local theX = x
  local theY = y
  if type(x) == "table" then
    theY = x.y
    theX = x.x
  end
  if name then
    print(name .. " (" .. theX .. ", " .. theY .. ")")
  else
    print("(" .. theX .. ", " .. theY .. ")")
  end
end

function Common.vector_distance(x1, y1, x2, y2)
  if type(x1) == "table" and type(y1) == "table" then
    local difference = Common.vector_sub(x1, y1)
    return Common.vector_length(difference.x, difference.y)
  elseif x1 and y1 and x2 and y2 then
    local diffx, diffy = Common.vector_sub(x1, y1, x2, y2)
    return Common.vector_length(diffx, diffy)
  end
  assert(false)
end

function Common.transform_local_to_world(local_frame, coords_to_transform)
  local new_orientation = Common.clean_angle_over_2pi(local_frame.orientation + coords_to_transform.orientation)
  local new_position = Common.vector_add(
    Common.vector_rotate(coords_to_transform.position, local_frame.orientation),
    local_frame.position)

  return {
    orientation = new_orientation,
    position = new_position
  }
end

function Common.equivalent(v1, v2, epsilon)
  epsilon = epsilon or 0.000001

  if v2 > v1 then
    return ((v2 - v1) <= epsilon)
  end
  if v1 > v2 then
    return ((v1 - v2) <= epsilon)
  end
  -- if v1 == v2 then
  return true
end

function Common.clamp_between(value, min, max)
  if value < min then
    return min
  end
  if value > max then
    return max
  end

  return value
end

function Common.zero_near_zero(value, epsilon)
  if Common.equivalent(0, value, epsilon) then
    return 0
  end

  return value
end

function Common.sign(v)
  -- http://lua-users.org/wiki/SimpleRound
  return (v >= 0 and 1) or -1
end
function Common.round(v, bracket)
  -- http://lua-users.org/wiki/SimpleRound
  bracket = bracket or 1
  return math.floor(v / bracket + Common.sign(v) * 0.5) * bracket
end

function Common.kmh_to_mps(kmh)
  return kmh * 1000 / 3600
end

function Common.mps_to_kmh(mps)
  return mps * 3600 / 1000
end

function Common.d2r(degrees)
  return degrees / 360 * 2 * math.pi
end

function Common.g_to_mss(g)
  return g * 9.8
end

function Common.mss_to_g(mss)
  return mss / 9.8
end

function Common.clean_angle_minus_pi_to_pi(angle_minus_pi_to_pi)
  while angle_minus_pi_to_pi > math.pi do
    angle_minus_pi_to_pi = angle_minus_pi_to_pi - 2 * math.pi
  end

  while angle_minus_pi_to_pi <= -math.pi do
    angle_minus_pi_to_pi = angle_minus_pi_to_pi + 2 * math.pi
  end

  return angle_minus_pi_to_pi
end

function Common.over_2pi(angle_minus_pi_to_pi)
  angle_minus_pi_to_pi = Common.clean_angle_minus_pi_to_pi(angle_minus_pi_to_pi)

  if angle_minus_pi_to_pi >= 0 and angle_minus_pi_to_pi <= math.pi then
    return angle_minus_pi_to_pi
  end

  return 2 * math.pi + angle_minus_pi_to_pi
end

function Common.clean_angle_over_2pi(angle_over_2pi)
  while angle_over_2pi >= 2 * math.pi do
    angle_over_2pi = angle_over_2pi - 2 * math.pi
  end
  return angle_over_2pi
end

function Common.from_over_2pi_to_minus_pi_to_pi(angle_over_2pi)
  angle_over_2pi = Common.clean_angle_over_2pi(angle_over_2pi)

  if angle_over_2pi >= 0 and angle_over_2pi <= math.pi then
    return angle_over_2pi
  end
  return -math.pi + (angle_over_2pi - math.pi)
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
function Common.get_arc_data(center, radius, start, finish)
  local normalized_start, start_length = Common.vector_normalize(Common.vector_sub(start, center))
  local normalized_finish, finish_length = Common.vector_normalize(Common.vector_sub(finish, center))

  print(radius, start_length, finish_length)


  if not Common.equivalent(start_length, radius) or not Common.equivalent(finish_length, radius) then
    return math.huge, math.huge, math.huge
  end

  local angle_start = math.atan2(normalized_start.y, normalized_start.x)
  local angle_finish = math.atan2(normalized_finish.y, normalized_finish.x)

  return Common.over_2pi(angle_finish - angle_start) * radius, Common.over_2pi(angle_start), Common.over_2pi(
    angle_finish
  )
end

return Common
