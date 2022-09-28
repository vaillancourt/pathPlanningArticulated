local Common = require "Common"

local test = {}

function test.Common_transform_local_to_world()
  local origin = {
    orientation = math.pi / 2,
    position = {x = 1, y = 0}
  }

  local txed = {
    orientation = math.pi / 2,
    position = {x = 1, y = 0}
  }

  local new_tx = Common.transform_local_to_world(origin, txed)
  Common.vector_print(new_tx.position)
  print(new_tx.orientation)
end

return test
