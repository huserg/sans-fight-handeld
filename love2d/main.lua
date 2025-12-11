local Game
local game

local function hasAssets()
  return love.filesystem.getInfo("Textures", "directory")
    and love.filesystem.getInfo("c2-export/sans_final.csv", "file")
end

local function mountRepoRoot()
  if hasAssets() then return true end

  local attempts = {}
  local function try(path, label)
    if not path then return false end
    table.insert(attempts, label or path)
    local ok = love.filesystem.mount(path, "")
    if ok and hasAssets() then
      return true
    elseif ok then
      pcall(love.filesystem.unmount, path)
    end
    return false
  end

  local base = love.filesystem.getSourceBaseDirectory()
  if try(base, "source base") then return true end
  if try(base .. "/..", "parent of source") then return true end
  if try(love.filesystem.getWorkingDirectory and love.filesystem.getWorkingDirectory(), "working directory") then return true end
  if try("..", "parent relative") then return true end

  error("Failed to mount repository root; ensure Textures/ and c2-export/ are alongside the .love (tried: " .. table.concat(attempts, ", ") .. ")")
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
