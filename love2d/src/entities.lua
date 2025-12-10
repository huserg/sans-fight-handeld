local Entities = {}
Entities.__index = Entities

local function rectsIntersect(a, b)
  return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function Entities.new(resources)
  local self = setmetatable({}, Entities)
  self.resources = resources
  self.bones = {}
  self.platforms = {}
  self.blasters = {}
  self.sans = {
    pose = "idle",
    head = "normal",
    sweat = false,
    x = 320,
    slamDamage = 1,
  }
  return self
end

function Entities:spawnBone(params)
  local dir = params.dir or 0
  local speed = params.speed or 0
  local length = params.length or 50
  table.insert(self.bones, {
    x = params.x,
    y = params.y,
    dir = dir,
    speed = speed,
    length = length,
    stab = params.stab,
    timer = params.delay or 0,
    repeatCount = params.repeatCount,
    spacing = params.spacing,
    timeAlive = 0,
  })
end

function Entities:spawnBlaster(params)
  table.insert(self.blasters, {
    x = params.x,
    y = params.y,
    targetX = params.tx,
    targetY = params.ty,
    angle = params.angle,
    charge = params.charge or 0.5,
    beam = params.beam or 0.5,
    timer = 0,
  })
end

function Entities:spawnPlatform(params)
  table.insert(self.platforms, {
    x = params.x,
    y = params.y,
    w = params.w or 120,
    h = 16,
    dir = params.dir or 0,
    speed = params.speed or 0,
  })
end

function Entities:switchSansPose(kind)
  self.sans.pose = kind or "idle"
end

function Entities:setSansHead(state)
  self.sans.head = state or "normal"
end

function Entities:setSansSweat(enabled)
  self.sans.sweat = enabled
end

function Entities:setSansPosition(x)
  self.sans.x = x
end

function Entities:setSlamDamage(value)
  self.sans.slamDamage = value or 1
end

function Entities:isOnPlatform(heart)
  local hb = {x = heart.x - heart.size, y = heart.y + heart.size, w = heart.size * 2, h = 4}
  for _, p in ipairs(self.platforms) do
    if rectsIntersect(hb, {x = p.x, y = p.y, w = p.w, h = p.h}) then
      heart.y = p.y - heart.size
      return true
    end
  end
  return false
end

function Entities:collidesWithHeart(heart)
  local hb = {x = heart.x - heart.size, y = heart.y - heart.size, w = heart.size * 2, h = heart.size * 2}
  for _, b in ipairs(self.bones) do
    if b.timer <= 0 then
      local w, h
      if b.dir == 0 or b.dir == 2 then
        w, h = 12, b.length
      else
        w, h = b.length, 12
      end
      local x, y = b.x, b.y
      if b.dir == 0 then y = y - h end
      if b.dir == 3 then x = x - w end
      if rectsIntersect(hb, {x = x, y = y, w = w, h = h}) then
        return true
      end
    end
  end
  for _, p in ipairs(self.blasters) do
    if p.timer > p.charge then
      local beamTime = p.timer - p.charge
      if beamTime < p.beam + 0.1 then
        local dx, dy = math.cos(p.angle), math.sin(p.angle)
        local relX, relY = hb.x + hb.w / 2 - p.x, hb.y + hb.h / 2 - p.y
        local along = relX * dx + relY * dy
        local perp = math.abs(-relX * dy + relY * dx)
        if along > -20 and along < 600 and perp < 24 then
          return true
        end
      end
    end
  end
  return false
end

function Entities:update(dt, heart, combatZone)
  for i = #self.platforms, 1, -1 do
    local p = self.platforms[i]
    if p.speed ~= 0 then
      if p.dir == 0 then p.y = p.y - p.speed * dt end
      if p.dir == 1 then p.x = p.x + p.speed * dt end
      if p.dir == 2 then p.y = p.y + p.speed * dt end
      if p.dir == 3 then p.x = p.x - p.speed * dt end
    end
    if p.y > combatZone.y2 + 200 or p.x < combatZone.x1 - 300 or p.x > combatZone.x2 + 300 then
      table.remove(self.platforms, i)
    end
  end

  for i = #self.bones, 1, -1 do
    local b = self.bones[i]
    b.timeAlive = b.timeAlive + dt
    if b.timer > 0 then
      b.timer = b.timer - dt
    else
      local speed = b.speed or 0
      if speed ~= 0 then
        if b.dir == 0 then b.y = b.y - speed * dt end
        if b.dir == 1 then b.x = b.x + speed * dt end
        if b.dir == 2 then b.y = b.y + speed * dt end
        if b.dir == 3 then b.x = b.x - speed * dt end
      end
    end
    if b.timeAlive > 10 then
      table.remove(self.bones, i)
    end
  end

  for i = #self.blasters, 1, -1 do
    local bl = self.blasters[i]
    bl.timer = bl.timer + dt
    if bl.timer > bl.charge + bl.beam then
      table.remove(self.blasters, i)
    end
  end
end

function Entities:drawBones()
  love.graphics.setColor(1, 1, 1)
  for _, b in ipairs(self.bones) do
    if b.timer <= 0 then
      if b.dir == 0 or b.dir == 2 then
        local img = self.resources.images.boneV
        local scaleY = b.length / img:getHeight()
        love.graphics.draw(img, b.x, b.y, 0, 1, scaleY, img:getWidth() / 2, img:getHeight())
      else
        local img = self.resources.images.boneH
        local scaleX = b.length / img:getWidth()
        love.graphics.draw(img, b.x, b.y, 0, scaleX, 1, 0, img:getHeight() / 2)
      end
    end
  end
end

function Entities:drawPlatforms()
  love.graphics.setColor(1, 1, 1)
  for _, p in ipairs(self.platforms) do
    local img = self.resources.images.platform
    local scaleX = p.w / img:getWidth()
    love.graphics.draw(img, p.x, p.y, 0, scaleX, 1, 0, img:getHeight())
  end
end

function Entities:drawBlasters()
  for _, bl in ipairs(self.blasters) do
    local img = self.resources.images.blaster
    love.graphics.push()
    love.graphics.translate(bl.x, bl.y)
    love.graphics.rotate(bl.angle)
    love.graphics.draw(img, 0, 0, 0, 0.5, 0.5, img:getWidth() / 2, img:getHeight())
    if bl.timer > bl.charge then
      local beamImg = self.resources.images.beam
      love.graphics.draw(beamImg, 0, -beamImg:getHeight() / 2, 0, 2, 1)
    end
    love.graphics.pop()
  end
end

function Entities:draw()
  self:drawPlatforms()
  self:drawBones()
  self:drawBlasters()
end

return Entities
