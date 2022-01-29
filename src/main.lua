io.stdout:setvbuf('no') -- This makes is so that print() statements print right away.

local sprite = 
{
  size = { x = 59, y = 24 },
  pivot = { x = 29, y = 24 }
}

local origin_sprite = {}
local destination_sprite = {}

local KeyboardState = {
  selected = "origin",
  move_up = false,
  move_down = false,
  move_left = false,
  move_right = false,
  rotate_cw = false,
  rotate_ccw = false,
}

local origin = {}
local destination = {}


local window_width, window_height = 768, 768
local turning_radius = 9.5

function love.load(args)
  love.window.setMode(window_width, window_height, {resizable=false})

  origin = {
    position = { x = window_width / 4, y = window_height / 2 },
    orientation = 0,
    image = love.graphics.newImage("assets/truck_origin.png")
  }

  destination = {
    position = { x = window_width * 3 / 4, y = window_height / 2 },
    orientation = 0,
    image = love.graphics.newImage("assets/truck_destination.png")
  }


end

function update_keyboard_state()
  if love.keyboard.isDown('i') then
    KeyboardState.selected = "origin"
  end
  if love.keyboard.isDown('o') then
    KeyboardState.selected = "destination"
  end
  
  KeyboardState.move_up = love.keyboard.isDown('w')
  KeyboardState.move_down = love.keyboard.isDown('s')
  KeyboardState.move_left = love.keyboard.isDown('a')
  KeyboardState.move_right = love.keyboard.isDown('d')
  KeyboardState.rotate_cw = love.keyboard.isDown('down')
  KeyboardState.rotate_ccw = love.keyboard.isDown('up')
end


function love.update(dt)
  update_keyboard_state()

  local updateable = nil
  if KeyboardState.selected == "origin" then
    updateable = origin
  else
    updateable = destination
  end

  if KeyboardState.move_down then updateable.position.y = updateable.position.y + 1 end
  if KeyboardState.move_up then updateable.position.y = updateable.position.y - 1 end
  if KeyboardState.move_left then updateable.position.x = updateable.position.x - 1 end
  if KeyboardState.move_right then updateable.position.x = updateable.position.x + 1 end
  if KeyboardState.rotate_cw then updateable.orientation = updateable.orientation - (math.pi / 32) end
  if KeyboardState.rotate_ccw then updateable.orientation = updateable.orientation + (math.pi / 32) end
end

function love.keyreleased(key)
  if key == "escape" then
     love.event.quit()
  end
end

function love.draw()

  -- drawing the origin
  love.graphics.draw(origin.image, origin.position.x, origin.position.y, origin.orientation, 1, 1, sprite.pivot.x, sprite.pivot.y)
  love.graphics.setColor(1, 0, 0)
  love.graphics.circle( "fill", origin.position.x, origin.position.y, 5 )
  love.graphics.setColor(1, 1, 1)

  -- drawing the destination
  love.graphics.draw(destination.image, destination.position.x, destination.position.y, destination.orientation, 1, 1, sprite.pivot.x, sprite.pivot.y)
  love.graphics.setColor(1, 0, 0)
  love.graphics.circle( "fill", destination.position.x, destination.position.y, 5 )
  love.graphics.setColor(1, 1, 1)

end

