local Common = require "Common"

local Vehicle = {
  position = {x = 0, y = 0},
  orientation = 0,
  left = {x = 0, y = 1},
  right = {x = 0, y = -1},
  head = {x = 1, y = 0},
  --turning_radius = 95,
  --left_center = {x = 0, y = 95},
  --right_center = {x = 0, y = -95}
}

function Vehicle.new(self, o, position, orientation)
--  require "pl.pretty".dump(self)
--  require "pl.pretty".dump(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self

  o.position = position
  o.orientation = orientation

  o:update()
  --require "pl.pretty".dump(self)
  --require "pl.pretty".dump(o)

  return o
end

function Vehicle.update(self)
  self.left = Common.vector_rotate({x = 1, y = 0}, Common.over_2pi(math.pi / 2 + self.orientation))
  self.right = Common.vector_rotate({x = 1, y = 0}, Common.over_2pi(-(math.pi / 2) + self.orientation))
  self.head = Common.vector_rotate({x = 1, y = 0}, self.orientation)
end

return Vehicle
