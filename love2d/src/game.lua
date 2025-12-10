local Resources = require("src.resources")
local Script = require("src.script")
local Entities = require("src.entities")

local Game = {}
Game.__index = Game

local WIDTH, HEIGHT = 640, 480

local function loadCSV(path)
  local base = love.filesystem.getSourceBaseDirectory()
  local file = assert(io.open(base .. "/../" .. path, "r"))
  local content = file:read("*a")
  file:close()
  return content
end

function Game.new()
  local self = setmetatable({}, Game)
  self.resources = Resources.new()
  self.entities = Entities.new(self.resources)
  love.graphics.setFont(self.resources.font)

  self.combatZone = {x1 = 200, y1 = 200, x2 = 440, y2 = 420, speed = 0}
  self.timelinePaused = false
  self.heart = {
    x = WIDTH / 2,
    y = HEIGHT / 2,
    vx = 0,
    vy = 0,
    mode = 0, -- 0 = red (free), 1 = blue (gravity)
    size = 14,
    gravity = 900,
    maxFallSpeed = 420,
    hp = 92,
    invuln = 0,
  }

  local scriptData = loadCSV("c2-export/sans_final.csv")
  self.script = Script.new(scriptData, self)
  self.state = "fight"
  self.message = ""
  return self
end

function Game:updateHeart(dt)
  local h = self.heart
  local moveSpeed = 220
  if h.mode == 0 then
    h.vx, h.vy = 0, 0
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then h.vx = h.vx - moveSpeed end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then h.vx = h.vx + moveSpeed end
    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then h.vy = h.vy - moveSpeed end
    if love.keyboard.isDown("down") or love.keyboard.isDown("s") then h.vy = h.vy + moveSpeed end
  else
    local onGround = self.entities:isOnPlatform(h)
    if onGround then
      h.vy = 0
      if love.keyboard.isDown("left") or love.keyboard.isDown("a") then h.vx = -moveSpeed end
      if love.keyboard.isDown("right") or love.keyboard.isDown("d") then h.vx = moveSpeed end
      if love.keyboard.isDown("space") or love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        h.vy = -360
      end
    else
      if love.keyboard.isDown("left") or love.keyboard.isDown("a") then h.vx = -moveSpeed end
      if love.keyboard.isDown("right") or love.keyboard.isDown("d") then h.vx = moveSpeed end
    end
    h.vy = h.vy + h.gravity * dt
    if h.vy > h.maxFallSpeed then h.vy = h.maxFallSpeed end
  end

  h.x = h.x + h.vx * dt
  h.y = h.y + h.vy * dt

  -- constrain to combat zone
  local cz = self.combatZone
  if h.x - h.size < cz.x1 then h.x = cz.x1 + h.size end
  if h.x + h.size > cz.x2 then h.x = cz.x2 - h.size end
  if h.y - h.size < cz.y1 then h.y = cz.y1 + h.size end
  if h.y + h.size > cz.y2 then h.y = cz.y2 - h.size end
end

function Game:update(dt)
  if self.state ~= "fight" then return end

  if self.heart.invuln > 0 then
    self.heart.invuln = math.max(0, self.heart.invuln - dt)
  end

  self.script:update(dt)
  self:updateHeart(dt)
  self.entities:update(dt, self.heart, self.combatZone)

  if self.entities:collidesWithHeart(self.heart) and self.heart.invuln <= 0 then
    self.heart.hp = math.max(0, self.heart.hp - 1)
    self.heart.invuln = 0.5
  end
end

function Game:drawCombatZone()
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)
  love.graphics.setColor(1, 1, 1)
  local cz = self.combatZone
  love.graphics.rectangle("line", cz.x1, cz.y1, cz.x2 - cz.x1, cz.y2 - cz.y1)
end

function Game:drawUI()
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(string.format("HP: %d", self.heart.hp), 10, 10)
  if self.message and self.message ~= "" then
    love.graphics.print(self.message, 10, 30)
  end
end

function Game:drawHeart()
  love.graphics.setColor(1, 0, 0)
  if self.heart.invuln > 0 and math.floor(self.heart.invuln * 20) % 2 == 0 then
    love.graphics.setColor(1, 0.7, 0.7)
  end
  love.graphics.circle("fill", self.heart.x, self.heart.y, self.heart.size)
  love.graphics.setColor(1, 1, 1)
end

function Game:draw()
  if self.state ~= "fight" then return end
  self:drawCombatZone()
  self.entities:draw()
  self:drawHeart()
  self:drawUI()
end

function Game:keypressed(key)
  if key == "escape" then
    love.event.quit()
  end
end

-- Timeline helpers called by script
function Game:resizeCombatZone(x1, y1, x2, y2)
  self.combatZone.x1, self.combatZone.y1, self.combatZone.x2, self.combatZone.y2 = x1, y1, x2, y2
end

function Game:setTimelinePaused(paused)
  self.timelinePaused = paused
end

function Game:teleportHeart(x, y)
  self.heart.x, self.heart.y = x, y
  self.heart.vx, self.heart.vy = 0, 0
end

function Game:setHeartMode(mode)
  self.heart.mode = mode
end

function Game:setHeartMaxFallSpeed(speed)
  self.heart.maxFallSpeed = speed
end

function Game:spawnBone(params)
  self.entities:spawnBone(params)
end

function Game:spawnGasterBlaster(params)
  self.entities:spawnBlaster(params)
end

function Game:spawnPlatform(params)
  self.entities:spawnPlatform(params)
end

function Game:setMessage(text)
  self.message = text or ""
end

function Game:setSansPose(kind)
  self.entities:switchSansPose(kind)
end

function Game:setSansHead(state)
  self.entities:setSansHead(state)
end

function Game:setSansSweat(enabled)
  self.entities:setSansSweat(enabled)
end

function Game:setSansPosition(x)
  self.entities:setSansPosition(x)
end

function Game:setSansSlamDamage(value)
  self.entities:setSlamDamage(value)
end

return Game
