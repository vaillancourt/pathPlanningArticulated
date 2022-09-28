local Common = require "Common"
local Vector2 = require "Vector2"

local Vehicle = {
  position = Vector2(0, 0),
  orientation = 0,
  left = Vector2(0, 1),
  right = Vector2(0, -1),
  head = Vector2(1, 0)
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
  self.left = Vector2(1, 0):rotate_copy(Common.over_2pi(math.pi / 2 + self.orientation))
  self.right = Vector2(1, 0):rotate_copy(Common.over_2pi(-(math.pi / 2) + self.orientation))
  self.head = Vector2(1, 0):rotate_copy(self.orientation)
end

return Vehicle
