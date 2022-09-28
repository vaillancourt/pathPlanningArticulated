local Vector2 = {
  x = 0,
  y = 0
}

package.loaded[...] = Vector2

setmetatable(
  Vector2,
  {
    __call = function(_, x_, y_)
      return Vector2.new(nil, x_, y_)
    end
  }
)

local Vector2_mt = {
  __index = Vector2,
  __tostring = function(self_)
    return "(" .. self_.x .. ", " .. self_.y .. ")"
  end,
  __call = function(_, x_, y_)
    return Vector2.new(nil, x_, y_)
  end,
  __unm = function(self_)
    return Vector2.new(nil, -self_.x, -self_.y)
  end,
  __add = function(lhs_, rhs_)
    return Vector2.new(nil, lhs_.x + rhs_.x, lhs_.y + rhs_.y)
  end,
  __sub = function(lhs_, rhs_)
    return Vector2.new(nil, lhs_.x - rhs_.x, lhs_.y - rhs_.y)
  end,
  __mul = function(lhs_, rhs_)
    if type(lhs_) == "table" and type(rhs_) == "number" then
      return Vector2.new(nil, lhs_.x * rhs_, lhs_.y * rhs_)
    elseif type(rhs_) == "table" and type(lhs_) == "number" then
      return Vector2.new(nil, rhs_.x * lhs_, rhs_.y * lhs_)
    end

    assert(false, "Incompatible types")
  end
}

function Vector2.new(o_, position_or_x_, y_)
  o_ = o_ or {}
  setmetatable(o_, Vector2_mt)

  if type(position_or_x_) == "table" then
    o_.x = position_or_x_.x
    o_.y = position_or_x_.y
  else
    o_.x = position_or_x_ or 0
    o_.y = y_ or 0
  end

  return o_
end

function Vector2.clone(self_)
  local o = {}
  setmetatable(o, Vector2_mt)

  o.x = self_.x
  o.y = self_.y

  return o
end

function Vector2.dot(self_, other_)
  return (self_.x * other_.x) + (self_.y * other_.y)
end

function Vector2.length2(self_)
  return self_.x * self_.x + self_.y * self_.y
end

function Vector2.length(self_)
  return math.sqrt(self_:length2())
end

function Vector2.normalize(self_)
  local length = self_:length()
  self_.x = self_.x / length
  self_.y = self_.y / length
  return length
end

function Vector2.rotate(self_, angle_over_2pi_)
  local x = math.cos(angle_over_2pi_) * self_.x - math.sin(angle_over_2pi_) * self_.y
  local y = math.sin(angle_over_2pi_) * self_.x + math.cos(angle_over_2pi_) * self_.y

  self_.x = x
  self_.y = y
end

function Vector2.rotate_copy(self_, angle_over_2pi_)
  local x = math.cos(angle_over_2pi_) * self_.x - math.sin(angle_over_2pi_) * self_.y
  local y = math.sin(angle_over_2pi_) * self_.x + math.cos(angle_over_2pi_) * self_.y

  return Vector2(x, y)
end

function Vector2.distance(self_, other_)
  local diff = self_ - other_
  return diff:length()
end

return Vector2
