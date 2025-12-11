local Game
local game

local function hasAssets()
  return love.filesystem.getInfo("Textures", "directory")
    and love.filesystem.getInfo("c2-export/sans_final.csv", "file")
end

local function realPath(path)
  if not path then return nil end
  if path:match("^@")=="@" then
    path = path:sub(2)
  end
  return path
end

local function scriptDirectory()
  local info = debug.getinfo(2, "S") or debug.getinfo(1, "S")
  if not info or not info.source then return nil end
  local source = realPath(info.source)
  if not source then return nil end
  local dir = source:match("(.*/)") or source:match("(.*\\)")
  if not dir then return nil end
  return dir:gsub("/$", "")
end

local function mountRepoRoot()
  if hasAssets() then return true end

  local attempts = {}
  local function try(path, label)
    if not path then return false end
    table.insert(attempts, label or path)
    local ok, err = love.filesystem.mount(path, "")
    if ok and hasAssets() then
      return true
    elseif ok then
      pcall(love.filesystem.unmount, path)
    end
    if err then
      table.insert(attempts, "  -> " .. tostring(err))
    end
    return false
  end

  local base = love.filesystem.getSourceBaseDirectory and love.filesystem.getSourceBaseDirectory()
  local scriptDir = scriptDirectory()
  local sourcePath = love.filesystem.getSource and realPath(love.filesystem.getSource())
  local working = love.filesystem.getWorkingDirectory and love.filesystem.getWorkingDirectory()

  if base and try(base, "source base") then return true end
  if base and try(base .. "/..", "parent of source") then return true end
  if sourcePath and try(sourcePath, "source path") then return true end
  if sourcePath and try(sourcePath .. "/..", "parent of source path") then return true end
  if scriptDir and try(scriptDir .. "/..", "parent of script") then return true end
  if try(working, "working directory") then return true end
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
