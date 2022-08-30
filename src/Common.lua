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
  local new_position =
    Common.vector_add(Common.vector_rotate(coords_to_transform.position, local_frame.orientation), local_frame.position)

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

  if not Common.equivalent(start_length, radius) or not Common.equivalent(finish_length, radius) then
    return math.huge, math.huge, math.huge
  end

  local angle_start = math.atan2(normalized_start.y, normalized_start.x)
  local angle_finish = math.atan2(normalized_finish.y, normalized_finish.x)

  return Common.over_2pi(angle_finish - angle_start) * radius, Common.over_2pi(angle_start), Common.over_2pi(
    angle_finish
  )
end

--[[
  Given a line equation (a, b, c), and a x coordinate, find the associated y value.

  No point is given if line_.b is equivalent to zero (nil is returnded).
]]
function Common.line_get_y(line_, x_)
  if not Common.equivalent(0, line_.b) then
    return -(line_.a / line_.b * x_) - (line_.c / line_.b)
  else
    return nil
  end
end

--[[
Given two circle centers and their radii, find a tangent to both circles if it exists.

https://cp-algorithms.com/geometry/tangents-to-two-circles.html

The page above doesn't clearly state what effects have the -/+ to the radii. AFAIK, assuming circles are centered on
similar y, and that circle 1 has a lower x than circle 2's:
- if both radii are positive: the line will be in y+ according to both circles
- if circle1's radius is negative and circle2's radius is positive: the line will pass between both circles, on the y-
  side for circle 1 and on the y+ side for circle 2
- if circle1's radius is positive and circle2's radius is negative: the line will pass between both circles, on the y+
  side for circle 1 and on the y- side for circle 2
- if both radii are negative: the line will be in y- according to both circles

@param circle_1_center_ the first circle, in the form of {x=..., y=...}
@param circle_2_center_ the second circle, in the form of {x=..., y=...}
@param circle_1_radius_ the radius of the first circle
@param circle_2_radius_ the radius of the second circle

@return the line equation in the form of {a=, b=, c=}, or nil if there is no tangent.
]]
function Common.get_tangent_to_two_circles(circle_1_center_, circle_2_center_, circle_1_radius_, circle_2_radius_)
  local c = {x = circle_2_center_.x - circle_1_center_.x, y = circle_2_center_.y - circle_1_center_.y}
  local r = circle_2_radius_ - circle_1_radius_
  local z = c.x * c.x + c.y * c.y

  local d = z - r * r

  if Common.equivalent(d, 0) then
    return nil
  end

  d = math.sqrt(math.abs(d))

  local a = (c.x * r + c.y * d) / z
  local b = (c.y * r - c.x * d) / z

  return {
    a = a,
    b = b,
    c = circle_1_radius_ - (a * circle_1_center_.x + b * circle_1_center_.y)
  }
end

--[[
Finds the point/s where a line and a circle intersect (if they exist).

See https://cp-algorithms.com/geometry/circle-line-intersection.html#solution

@param line_ the line in the form { a=..., b=..., c=... }
@param circle_ the circle in the form { position = { x=..., y=..., }, radius= ... }

@return list of 0, 1 or 2 points in the form of { x=..., y=... }
]]
function Common.find_intersection_line_circle(line_, circle_)
  local r = circle_.radius
  local a = line_.a
  local b = line_.b
  local c = line_.c + (a * circle_.position.x + b * circle_.position.y)

  local x0 = -a * c / (a * a + b * b)
  local y0 = -b * c / (a * a + b * b)

  local epsilon = 0.000001
  if c * c > r * r * (a * a + b * b) + epsilon then
    return {}
  elseif Common.equivalent(0, c * c - r * r * (a * a + b * b), epsilon) then
    return {{x = x0 + circle_.position.x, y = y0 + circle_.position.y}}
  else
    local d = r * r - c * c / (a * a + b * b)
    local mult = math.sqrt(d / (a * a + b * b))
    return {
      {x = x0 + b * mult + circle_.position.x, y = y0 - a * mult + circle_.position.y},
      {x = x0 - b * mult + circle_.position.x, y = y0 + a * mult + circle_.position.y}
    }
  end
end

return Common
