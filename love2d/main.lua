-- Bad Time Simulator (Sans Fight) - Love2D Port
-- Main entry point

local Game = require("src.core.game")

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setBackgroundColor(0, 0, 0)
    Game:load()
end

function love.update(dt)
    Game:update(dt)
end

function love.draw()
    Game:draw()
end

function love.keypressed(key)
    Game:keypressed(key)
end

function love.keyreleased(key)
    Game:keyreleased(key)
end

function love.gamepadpressed(joystick, button)
    Game:gamepadpressed(joystick, button)
end

function love.gamepadreleased(joystick, button)
    Game:gamepadreleased(joystick, button)
end

function love.joystickadded(joystick)
    Game:joystickadded(joystick)
end
