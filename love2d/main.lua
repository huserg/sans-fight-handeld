local Game = require("src.game")
local game

function love.load()
  love.math.setRandomSeed(os.time())
  game = Game.new()
end

function love.update(dt)
  if game then
    game:update(dt)
  end
end

function love.draw()
  if game then
    game:draw()
  end
end

function love.keypressed(key)
  if game then
    game:keypressed(key)
  end
end
