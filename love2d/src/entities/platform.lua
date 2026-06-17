-- Platform Entity
-- A moving surface the player heart can stand on in blue (gravity) mode.
-- Built by tiling a small sprite across the requested width.

local Platform = {}
Platform.__index = Platform

local sprites = { loaded = false }

local function loadSprites()
    if sprites.loaded then return end
    sprites.tile = love.graphics.newImage("assets/sprites/platform1.png")
    sprites.tile:setFilter("nearest", "nearest")
    sprites.tileW, sprites.tileH = sprites.tile:getDimensions()
    sprites.loaded = true
end

-- x = left edge, y = top surface
-- reverse (truthy/non-zero) makes the platform ping-pong inside the combat zone
-- instead of travelling off-screen, matching the original Reverse behavior.
function Platform.new(x, y, width, direction, speed, reverse, combatZone)
    loadSprites()

    local self = setmetatable({}, Platform)
    self.x = x
    self.y = y
    self.width = math.max(width or 0, sprites.tileW)
    self.height = sprites.tileH
    self.isPlatform = true
    self.dead = false

    self.direction = direction or 0
    self.speed = speed or 0
    self.reverse = (reverse ~= nil and reverse ~= 0) and true or false
    self.combatZone = combatZone

    self:applyVelocity()

    return self
end

-- Derive velocity from the current direction (0=right,1=down,2=left,3=up)
function Platform:applyVelocity()
    local s = self.speed
    local vx, vy = 0, 0
    if self.direction == 0 then vx = s
    elseif self.direction == 1 then vy = s
    elseif self.direction == 2 then vx = -s
    elseif self.direction == 3 then vy = -s end
    self.vx, self.vy = vx, vy
end

-- Flip direction (0<->2, 1<->3) when the leading edge reaches the zone edge.
function Platform:bounce()
    local zx1, zy1, zx2, zy2 = self.combatZone:getBounds()
    local d = self.direction
    if d == 0 and self.x + self.width >= zx2 then
        self.direction = 2
    elseif d == 1 and self.y + self.height >= zy2 then
        self.direction = 3
    elseif d == 2 and self.x <= zx1 then
        self.direction = 0
    elseif d == 3 and self.y <= zy1 then
        self.direction = 1
    else
        return
    end
    self:applyVelocity()
end

function Platform:update(dt)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    if self.reverse and self.combatZone then
        self:bounce()
    elseif self.x + self.width < -200 or self.x > 840
        or self.y < -200 or self.y > 680 then
        self.dead = true
    end
end

-- Reusable quad for the partial last tile (one per atlas size, cached on the
-- module so we don't allocate a fresh quad every frame).
local function partialQuad(width)
    if not sprites.partial then
        sprites.partial = love.graphics.newQuad(0, 0, width, sprites.tileH,
            sprites.tile:getDimensions())
    else
        sprites.partial:setViewport(0, 0, width, sprites.tileH)
    end
    return sprites.partial
end

function Platform:draw()
    love.graphics.setColor(1, 1, 1)
    local tw = sprites.tileW
    -- Snap the origin to integer pixels: with nearest-neighbor filtering a
    -- fractional position makes neighbouring tiles sample across their edges,
    -- producing 1px seams/gaps. Tiles are then laid at exact tw multiples so
    -- they abut perfectly.
    local ox = math.floor(self.x + 0.5)
    local oy = math.floor(self.y + 0.5)
    local total = math.floor(self.width)

    local drawn = 0
    while drawn < total do
        local segment = math.min(tw, total - drawn)
        if segment >= tw then
            love.graphics.draw(sprites.tile, ox + drawn, oy)
        else
            -- Final partial tile: crop the source to the remaining width.
            love.graphics.draw(sprites.tile, partialQuad(segment), ox + drawn, oy)
        end
        drawn = drawn + tw
    end
end

return Platform
