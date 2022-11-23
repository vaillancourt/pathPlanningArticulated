-- https://stackoverflow.com/a/54899251
local Common = {}
package.loaded[...] = Common

local Vector2 = require "Vector2"

-- luacheck: globals love

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

-- An atan2 version that returns an angle in the range of [0..2pi).
function Common.atan2(y_, x_)
  return Common.over_2pi(math.atan2(y_, x_))
end

-- An atan2 version that returns an angle in the range of [0..2pi); makes sure it's normalized first.
function Common.normalize_atan2(coord_)
  local v2 = Vector2:new(coord_.x, coord_.y)
  v2:normalize()
  return Common.atan2(v2.y, v2.x)
end

function Common.clean_angle_over_2pi(angle_over_2pi)
  while angle_over_2pi >= 2 * math.pi do
    angle_over_2pi = angle_over_2pi - 2 * math.pi
  end
  while angle_over_2pi < 0 do
    angle_over_2pi = angle_over_2pi + 2 * math.pi
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

--[[
  Get the distance between start_ and finish_; assumes both are in the range of [0..2pi).

  @param start_ starting value of the angle.
  @param finish_ final value.
  @param direction_ "CCW" if start_ and finish_ should be considered in the counter-clockwise direction, or "CW"
        if the angles are in the clockwise direction.

  @return the distance between the angles, or 0 if direction_ is not "CW" or "CCW". 
]]
function Common.angle_distance(start_, finish_, direction_)
  if direction_ == "CCW" then
    if start_ > finish_ then
      return math.pi * 2 - (start_ - finish_)
    end

    return finish_ - start_
  end
  if direction_ == "CW" then
    if finish_ > start_ then
      return math.pi * 2 - (finish_ - start_)
    end

    return start_ - finish_
  end
  return 0
end

--- Computes the arc between a starting point and a finishing point on a circle.
-- The function expects:
-- - that the start and finish are in counter-clock-wise order.
-- - that the angles are all in the range of [0, 2pi[, with 0 being on x+
--
-- If the points presented don't appear to be on the circle, math.huge is returned for all the values.
--
-- @param center_ Vector2 of the coordinates of the center of the circle.
-- @param radius_ number value of the radius of the circle
-- @param start_ Vector2 of a point on the circle where the angle "starts"; should be on the circle edge.
-- @param finish_ Vector2 of a point on the circle where the angle "finishes"; should be on the circle edge.
-- @param dir_ The direction of start_ w.r.t. finish_: 1 for counter-clockwise, -1 for clockwise.
-- @param epsilon_ The epsilon value when checking for equivalence.
--
-- @return angle between the two points, or math.huge if both points are not on the circle edge.
-- @return the angle where start is, or math.huge if both points are not on the circle edge.
-- @return the angle where finish is, or math.hug if both points are not on the circle edge.
function Common.get_arc_data(center_, radius_, start_, finish_, dir_, epsilon_)
  local normalized_start = start_ - center_
  local start_length = normalized_start:normalize()
  local normalized_finish = finish_ - center_
  local finish_length = normalized_finish:normalize()

  if not Common.equivalent(start_length, radius_, epsilon_) or not Common.equivalent(finish_length, radius_, epsilon_) then
    -- print("oops", radius_, start_length, finish_length)
    error("error--oops")
    return math.huge, math.huge, math.huge
  end
  --print("oook", radius_, start_length, finish_length)

  local angle_start = Common.atan2(normalized_start.y, normalized_start.x)
  local angle_finish = Common.atan2(normalized_finish.y, normalized_finish.x)

  local range = angle_finish - angle_start
  if dir_ == -1 then
    range = angle_start - angle_finish
  end
  return Common.clean_angle_over_2pi(range) * radius_, Common.clean_angle_over_2pi(angle_start), Common.clean_angle_over_2pi(
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
    return {Vector2(x0 + circle_.position.x, y0 + circle_.position.y)}
  else
    local d = r * r - c * c / (a * a + b * b)
    local mult = math.sqrt(d / (a * a + b * b))
    return {
      Vector2(x0 + b * mult + circle_.position.x, y0 - a * mult + circle_.position.y),
      Vector2(x0 - b * mult + circle_.position.x, y0 + a * mult + circle_.position.y)
    }
  end
end

--[[
  Given two cricles, check if they touch.

  @param circle1_ {position = {x = .., y = ..}, radius = ..}
  @param circle2_ {position = {x = .., y = ..}, radius = ..}

  @retval true if they touch
  @retval false if they don't touch
]]
function Common.do_circles_overlap(circle1_, circle2_)
  local center_to_center_distance = circle1_.position:distance(circle2_.position)
  return center_to_center_distance < (circle1_.radius + circle2_.radius)
end

--[[
  Given two cricles, check if one is completely within the other.

  @param circle1_ {position = {x = .., y = ..}, radius = ..}
  @param circle2_ {position = {x = .., y = ..}, radius = ..}

  @retval true if circle1_ is completely within circle2_ or circle2_ is completely within circle1_
  @retval false otherwise
]]
function Common.does_one_circle_cover_circle(circle1_, circle2_)
  local center_to_center_distance = circle1_.position:distance(circle2_.position)
  return (center_to_center_distance + circle2_.radius) < circle1_.radius or
    (center_to_center_distance + circle1_.radius) < circle2_.radius
end

--[[
  With the three sides of the triangle supplied, finds the angles of the triangle.
]]
function Common.triangle_anlges_from_side_lengths(side_a_, side_b_, side_c_)
  local a2 = side_a_ * side_a_
  local b2 = side_b_ * side_b_
  local c2 = side_c_ * side_c_

  local A = math.acos((b2 + c2 - a2) / (2 * side_b_ * side_c_))
  local B = math.acos((a2 + c2 - b2) / (2 * side_a_ * side_c_))
  local C = math.acos((a2 + b2 - c2) / (2 * side_a_ * side_b_))

  return {A = A, B = B, C = C}
end

--[[
  Check if line_1_ is equivalent to line_2_. Lines not being directed, one may want to also check if they're oriented the
  same if needed.
  @param line_1_ a line in the form of {a=.., b=.., c=..}
  @param line_2_ a line in the form of {a=.., b=.., c=..}

  @retval true if the inputs represent the same line
  @retval false if the inputs represent different lines
]]
function Common.is_same_line(line_1_, line_2_)
  if Common.equivalent(line_1_.b, 0) and Common.equivalent(line_2_.b, 0) then
    -- the line is vertical, check if both are on the same x value
    local x1 = -(line_1_.a / line_1_.b)
    local x2 = -(line_2_.a / line_2_.b)
    return Common.equivalent(x1, x2)
  end

  if Common.equivalent(line_1_.b, 0) or Common.equivalent(line_2_.b, 0) then
    -- one line is vertical, the other is not
    return false
  end

  -- if it's the same line, given the same arbitrary x, both should have the same associated y
  -- using y = -((a/b)*x) - (c/b), where x = 1
  local y1 = -((line_1_.a / line_1_.b) * 1) - (line_1_.c / line_1_.b)
  local y2 = -((line_2_.a / line_2_.b) * 1) - (line_2_.c / line_2_.b)

  return Common.equivalenty(y1, y2)
end

function Common.get_line_from_point_slope(point_a_, angle_over_2pi_)
  local pa = point_a_
  local pb = point_a_ + Vector2(1, 0):rotate_copy(angle_over_2pi_)

  return {
    a = pa.y - pb.y,
    b = pb.x - pa.x,
    c = pa.x * pb.y - pb.x * pa.y
  }
end

--[[
  https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line#Line_defined_by_an_equation
]]
function Common.get_distance_line_point(line_, point_)
  local a = line_.a
  local b = line_.b
  local c = line_.c
  local x0 = point_.x
  local y0 = point_.y

  local a2b2 = a * a + b * b
  local distance = math.abs(a * x0 + b * y0 + c) / math.sqrt(a2b2)
  local position_on_line = Vector2((b * (b * x0 - a * y0) - a * c) / a2b2, (a * (-b * x0 + a * y0) - b * c) / a2b2)

  return distance, position_on_line
end

--[[
  Linear interpolation between s_ (start), e_ (end), at time t_, assuming t_ is in [0..1)
]]
function Common.lerp(s_, e_, t_)
  return s_ + t_ * (e_ - s_)
end

return Common
