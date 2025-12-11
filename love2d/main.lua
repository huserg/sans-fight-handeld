local Game
local game

local function mountRepoRoot()
  local base = love.filesystem.getSourceBaseDirectory()
  local parent = base .. "/.."
  local ok = love.filesystem.mount(parent, "")
  if not ok then
    error("Failed to mount repository root; ensure Textures and data folders are available")
  end
end

function love.load()
  love.math.setRandomSeed(os.time())
  mountRepoRoot()
  Game = require("src.game")
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
